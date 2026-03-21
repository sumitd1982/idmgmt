import 'dart:convert';

final class AppUser {
  static Map<String, dynamic> _parsePrefs(dynamic prefs) {
    if (prefs == null) return {};
    if (prefs is Map<String, dynamic>) return prefs;
    if (prefs is String) {
      if (prefs.isEmpty) return {};
      try {
        return jsonDecode(prefs) as Map<String, dynamic>;
      } catch (_) { return {}; }
    }
    return {};
  }
  final String id;
  final String? firebaseUid;
  final String? email;
  final String? phone;
  final String fullName;
  final String? photoUrl;
  final String role;
  final bool isActive;
  final String? schoolId;
  final bool needsOnboarding;
  final AppEmployee? employee;

  const AppUser({
    required this.id,
    this.firebaseUid,
    this.email,
    this.phone,
    required this.fullName,
    this.photoUrl,
    required this.role,
    required this.isActive,
    this.schoolId,
    this.needsOnboarding = false,
    this.preferences = const {},
    this.employee,
  });

  final Map<String, dynamic> preferences;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id:              json['id'] as String,
    firebaseUid:     json['firebase_uid'] as String?,
    email:           json['email'] as String?,
    phone:           json['phone'] as String?,
    fullName:        json['full_name'] as String? ?? '',
    photoUrl:        json['photo_url'] as String?,
    role:            json['role'] as String? ?? 'viewer',
    isActive:        (json['is_active'] is int) ? (json['is_active'] as int) == 1 : (json['is_active'] as bool? ?? true),
    schoolId:        json['school_id'] as String?,
    needsOnboarding: json['needs_onboarding'] as bool? ?? false,
    preferences:     _parsePrefs(json['preferences']),
    employee:        json['employee'] != null
                       ? AppEmployee.fromJson(json['employee'] as Map<String, dynamic>)
                       : null,
  );

  bool get isAdmin       => ['super_admin','school_admin','branch_admin', 'school_owner'].contains(role);
  bool get isSchoolOwner => role == 'school_owner';
  bool get isPrincipal   => role == 'principal';
  bool get isTeacher     => role.contains('teacher');
  bool get isParent      => role == 'parent';
  bool get isSuperAdmin  => role == 'super_admin';

  String get displayName => fullName.isNotEmpty ? fullName : email ?? phone ?? 'User';
}

class AppEmployee {
  final String id;
  final String schoolId;
  final String? branchId;
  final String employeeId;
  final String firstName;
  final String lastName;
  final String roleName;
  final int roleLevel;
  final bool canApprove;
  final bool canUploadBulk;
  final List<String> assignedClasses;

  const AppEmployee({
    required this.id,
    required this.schoolId,
    this.branchId,
    required this.employeeId,
    required this.firstName,
    required this.lastName,
    required this.roleName,
    required this.roleLevel,
    required this.canApprove,
    required this.canUploadBulk,
    required this.assignedClasses,
  });

  factory AppEmployee.fromJson(Map<String, dynamic> json) => AppEmployee(
    id:             json['id'] as String,
    schoolId:       json['school_id'] as String,
    branchId:       json['branch_id'] as String?,
    employeeId:     json['employee_id'] as String,
    firstName:      json['first_name'] as String? ?? '',
    lastName:       json['last_name'] as String? ?? '',
    roleName:       json['role_name'] as String? ?? '',
    roleLevel:      json['role_level'] as int? ?? 9,
    canApprove:     (json['can_approve'] as int?) == 1,
    canUploadBulk:  (json['can_upload_bulk'] as int?) == 1,
    assignedClasses: (json['assigned_classes'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ?? [],
  );

  String get fullName => '$firstName $lastName';
}
