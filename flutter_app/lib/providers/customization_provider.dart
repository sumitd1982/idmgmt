// ============================================================
// Customization Providers — Menu Config, Dashboard Widgets,
//                           Review Templates
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

// ── Data Models ───────────────────────────────────────────────

class NavItemConfig {
  final String key;
  final String label;
  final String path;
  final bool visible;
  final int sortOrder;

  const NavItemConfig({
    required this.key,
    required this.label,
    required this.path,
    required this.visible,
    required this.sortOrder,
  });

  factory NavItemConfig.fromJson(Map<String, dynamic> j) => NavItemConfig(
        key:       j['key']        as String,
        label:     j['label']      as String,
        path:      j['path']       as String,
        visible:   j['visible']    as bool? ?? true,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'key':        key,
        'label':      label,
        'path':       path,
        'visible':    visible,
        'sort_order': sortOrder,
      };

  NavItemConfig copyWith({bool? visible, int? sortOrder}) => NavItemConfig(
        key:       key,
        label:     label,
        path:      path,
        visible:   visible ?? this.visible,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

class WidgetConfig {
  final String key;
  final String label;
  final bool visible;
  final int sortOrder;
  final int colSpan; // 1 = half-width, 2 = full-width

  const WidgetConfig({
    required this.key,
    required this.label,
    required this.visible,
    required this.sortOrder,
    this.colSpan = 2,
  });

  factory WidgetConfig.fromJson(Map<String, dynamic> j) => WidgetConfig(
        key:       j['key']        as String,
        label:     j['label']      as String? ?? j['key'] as String,
        visible:   j['visible']    as bool? ?? true,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
        colSpan:   (j['col_span']  as num?)?.toInt() ?? 2,
      );

  Map<String, dynamic> toJson() => {
        'key':        key,
        'label':      label,
        'visible':    visible,
        'sort_order': sortOrder,
        'col_span':   colSpan,
      };

  WidgetConfig copyWith({bool? visible, int? sortOrder, int? colSpan}) => WidgetConfig(
        key:       key,
        label:     label,
        visible:   visible ?? this.visible,
        sortOrder: sortOrder ?? this.sortOrder,
        colSpan:   colSpan  ?? this.colSpan,
      );
}

class ReviewTemplateField {
  final String fieldKey;
  final String label;
  final bool visible;
  final bool required;

  const ReviewTemplateField({
    required this.fieldKey,
    required this.label,
    required this.visible,
    this.required = false,
  });

  factory ReviewTemplateField.fromJson(Map<String, dynamic> j) => ReviewTemplateField(
        fieldKey: j['field_key'] as String,
        label:    j['label']     as String,
        visible:  j['visible']   as bool? ?? true,
        required: j['required']  as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'field_key': fieldKey,
        'label':     label,
        'visible':   visible,
        'required':  required,
      };

  ReviewTemplateField copyWith({bool? visible, bool? required}) => ReviewTemplateField(
        fieldKey: fieldKey,
        label:    label,
        visible:  visible  ?? this.visible,
        required: required ?? this.required,
      );
}

class ReviewTemplateSection {
  final String sectionName;
  final int sortOrder;
  final List<ReviewTemplateField> fields;

  const ReviewTemplateSection({
    required this.sectionName,
    required this.sortOrder,
    required this.fields,
  });

  factory ReviewTemplateSection.fromJson(Map<String, dynamic> j) => ReviewTemplateSection(
        sectionName: j['section_name'] as String,
        sortOrder:   (j['sort_order'] as num?)?.toInt() ?? 0,
        fields: (j['fields'] as List<dynamic>? ?? [])
            .map((f) => ReviewTemplateField.fromJson(f as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'section_name': sectionName,
        'sort_order':   sortOrder,
        'fields':       fields.map((f) => f.toJson()).toList(),
      };

  ReviewTemplateSection copyWith({String? sectionName, int? sortOrder, List<ReviewTemplateField>? fields}) =>
      ReviewTemplateSection(
        sectionName: sectionName ?? this.sectionName,
        sortOrder:   sortOrder   ?? this.sortOrder,
        fields:      fields      ?? this.fields,
      );
}

class ReviewTemplate {
  final String id;
  final String? schoolId;
  final String entityType; // 'student' | 'teacher'
  final String name;
  final String? description;
  final String layoutStyle; // 'side_by_side' | 'stacked' | 'card'
  final List<ReviewTemplateSection> sections;
  final bool isDefault;
  final bool isSystem;

  const ReviewTemplate({
    required this.id,
    this.schoolId,
    required this.entityType,
    required this.name,
    this.description,
    required this.layoutStyle,
    required this.sections,
    required this.isDefault,
    required this.isSystem,
  });

  factory ReviewTemplate.fromJson(Map<String, dynamic> j) {
    final rawSections = j['sections'];
    final sectionsList = rawSections is List ? rawSections : [];
    return ReviewTemplate(
      id:          j['id']          as String,
      schoolId:    j['school_id']   as String?,
      entityType:  j['entity_type'] as String,
      name:        j['name']        as String,
      description: j['description'] as String?,
      layoutStyle: j['layout_style'] as String? ?? 'side_by_side',
      sections: sectionsList
          .map((s) => ReviewTemplateSection.fromJson(s as Map<String, dynamic>))
          .toList(),
      isDefault: j['is_default'] as bool? ?? false,
      isSystem:  j['is_system']  as bool? ?? j['school_id'] == null,
    );
  }
}

// ── Provider Keys ─────────────────────────────────────────────

class _MenuConfigKey {
  final String role;
  final String? schoolId;
  const _MenuConfigKey(this.role, this.schoolId);
  @override bool operator ==(Object o) =>
      o is _MenuConfigKey && o.role == role && o.schoolId == schoolId;
  @override int get hashCode => Object.hash(role, schoolId);
}

class _DashboardConfigKey {
  final String role;
  final String? schoolId;
  const _DashboardConfigKey(this.role, this.schoolId);
  @override bool operator ==(Object o) =>
      o is _DashboardConfigKey && o.role == role && o.schoolId == schoolId;
  @override int get hashCode => Object.hash(role, schoolId);
}

class _ReviewTemplateKey {
  final String type;
  final String? schoolId;
  const _ReviewTemplateKey(this.type, this.schoolId);
  @override bool operator ==(Object o) =>
      o is _ReviewTemplateKey && o.type == type && o.schoolId == schoolId;
  @override int get hashCode => Object.hash(type, schoolId);
}

// ── Providers ─────────────────────────────────────────────────

final menuConfigProvider = FutureProvider.family<List<NavItemConfig>, _MenuConfigKey>(
  (ref, key) async {
    try {
      final params = <String, dynamic>{'role': key.role};
      if (key.schoolId != null) params['school_id'] = key.schoolId!;
      final data = await ApiService().get('/customization/menu-config', params: params);
      final items = (data['data']?['items'] as List<dynamic>? ?? []);
      final configs = items
          .map((e) => NavItemConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      configs.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return configs;
    } catch (_) {
      return []; // fallback to hardcoded defaults in app_shell.dart
    }
  },
);

final dashboardConfigProvider = FutureProvider.family<List<WidgetConfig>, _DashboardConfigKey>(
  (ref, key) async {
    try {
      final params = <String, dynamic>{'role': key.role};
      if (key.schoolId != null) params['school_id'] = key.schoolId!;
      final data = await ApiService().get('/customization/dashboard-config', params: params);
      final widgets = (data['data']?['widgets'] as List<dynamic>? ?? []);
      final configs = widgets
          .map((e) => WidgetConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      configs.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return configs;
    } catch (_) {
      return [];
    }
  },
);

final reviewTemplatesProvider = FutureProvider.family<List<ReviewTemplate>, _ReviewTemplateKey>(
  (ref, key) async {
    final params = <String, dynamic>{'type': key.type};
    if (key.schoolId != null) params['school_id'] = key.schoolId!;
    final data = await ApiService().get('/customization/review-templates', params: params);
    final list = data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => ReviewTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

// Convenience constructors for provider families
_MenuConfigKey menuConfigKey(String role, String? schoolId) => _MenuConfigKey(role, schoolId);
_DashboardConfigKey dashboardConfigKey(String role, String? schoolId) => _DashboardConfigKey(role, schoolId);
_ReviewTemplateKey reviewTemplateKey(String type, String? schoolId) => _ReviewTemplateKey(type, schoolId);
