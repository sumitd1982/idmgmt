// ============================================================
// Employee Model
// ============================================================

class EmployeeRecord {
  final String id;
  final String employeeId;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final String email;
  final String? phone;
  final String roleName;
  final int roleLevel;
  final String? branchName;
  final String? branchId;
  final String? schoolName;
  final String? schoolId;
  final String? managerName;
  final String? reportsToEmpId;
  final bool canApprove;
  final bool canUploadBulk;
  final bool isActive;
  final bool isHidden;
  final List<String> extraRoles;

  const EmployeeRecord({
    required this.id,
    required this.employeeId,
    required this.firstName,
    required this.lastName,
    this.photoUrl,
    required this.email,
    this.phone,
    required this.roleName,
    required this.roleLevel,
    this.branchName,
    this.branchId,
    this.schoolName,
    this.schoolId,
    this.managerName,
    this.reportsToEmpId,
    required this.canApprove,
    required this.canUploadBulk,
    required this.isActive,
    this.isHidden = false,
    this.extraRoles = const [],
  });

  String get fullName => '$firstName $lastName';

  factory EmployeeRecord.fromJson(Map<String, dynamic> j) => EmployeeRecord(
        id:            j['id']             as String,
        employeeId:    j['employee_id']    as String? ?? '',
        firstName:     j['first_name']     as String? ?? '',
        lastName:      j['last_name']      as String? ?? '',
        photoUrl:      j['photo_url']      as String?,
        email:         j['email']          as String? ?? '',
        phone:         j['phone']          as String?,
        roleName:      j['role_name']      as String? ?? '',
        roleLevel:     j['role_level']     as int? ?? 9,
        branchName:    j['branch_name']    as String?,
        branchId:      j['branch_id']      as String?,
        schoolName:    j['school_name']    as String?,
        schoolId:      j['school_id']      as String?,
        managerName:   j['manager_name']   as String?,
        reportsToEmpId:j['reports_to_emp_id'] as String?,
        canApprove:    (j['can_approve']   as int?) == 1,
        canUploadBulk: (j['can_upload_bulk'] as int?) == 1,
        isActive:      (j['is_active']     as int?) != 0,
        isHidden:      (j['is_hidden']     as int?) == 1,
        extraRoles:    (j['extra_roles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      );

  static List<EmployeeRecord> mockList() => [
        const EmployeeRecord(id: 'e1', employeeId: 'EMP001', firstName: 'Rajesh',  lastName: 'Sharma',  email: 'rajesh@school.in',  phone: '9876543210', roleName: 'Principal',      roleLevel: 1, branchName: 'Main Branch',  schoolName: 'Green Valley School', canApprove: true,  canUploadBulk: true,  isActive: true),
        const EmployeeRecord(id: 'e2', employeeId: 'EMP002', firstName: 'Sunita',  lastName: 'Rao',     email: 'sunita@school.in',  phone: '9123456789', roleName: 'Vice Principal', roleLevel: 2, branchName: 'Main Branch',  schoolName: 'Green Valley School', canApprove: true,  canUploadBulk: true,  isActive: true),
        const EmployeeRecord(id: 'e3', employeeId: 'EMP003', firstName: 'Arjun',   lastName: 'Nair',    email: 'arjun@school.in',   phone: '9234567890', roleName: 'Head Teacher',   roleLevel: 3, branchName: 'Main Branch',  schoolName: 'Green Valley School', canApprove: true,  canUploadBulk: false, isActive: true),
        const EmployeeRecord(id: 'e4', employeeId: 'EMP004', firstName: 'Divya',   lastName: 'Menon',   email: 'divya@school.in',   phone: '9345678901', roleName: 'Head Teacher',   roleLevel: 3, branchName: 'East Campus',  schoolName: 'Green Valley School', canApprove: true,  canUploadBulk: false, isActive: true),
        const EmployeeRecord(id: 'e5', employeeId: 'EMP005', firstName: 'Kiran',   lastName: 'Joshi',   email: 'kiran@school.in',   phone: '9456789012', roleName: 'Vice Principal', roleLevel: 2, branchName: 'West Campus',  schoolName: 'Green Valley School', canApprove: true,  canUploadBulk: true,  isActive: true),
        const EmployeeRecord(id: 'e6', employeeId: 'EMP006', firstName: 'Priya',   lastName: 'Gupta',   email: 'priya@school.in',   phone: '9567890123', roleName: 'Senior Teacher', roleLevel: 4, branchName: 'Main Branch',  schoolName: 'Green Valley School', canApprove: false, canUploadBulk: false, isActive: true),
        const EmployeeRecord(id: 'e7', employeeId: 'EMP007', firstName: 'Rohit',   lastName: 'Verma',   email: 'rohit@school.in',   phone: '9678901234', roleName: 'Class Teacher',  roleLevel: 5, branchName: 'Main Branch',  schoolName: 'Green Valley School', canApprove: false, canUploadBulk: false, isActive: true),
        const EmployeeRecord(id: 'e8', employeeId: 'EMP008', firstName: 'Kavya',   lastName: 'Iyer',    email: 'kavya@school.in',   phone: '9789012345', roleName: 'Subject Teacher', roleLevel: 6, branchName: 'Main Branch', schoolName: 'Green Valley School', canApprove: false, canUploadBulk: false, isActive: false),
        const EmployeeRecord(id: 'e9', employeeId: 'EMP009', firstName: 'Suresh',  lastName: 'Patel',   email: 'suresh@school.in',  phone: '9890123456', roleName: 'Senior Teacher', roleLevel: 4, branchName: 'East Campus',  schoolName: 'Green Valley School', canApprove: false, canUploadBulk: false, isActive: true),
        const EmployeeRecord(id:'e10', employeeId: 'EMP010', firstName: 'Anita',   lastName: 'Reddy',   email: 'anita@school.in',   phone: '9901234567', roleName: 'Class Teacher',  roleLevel: 5, branchName: 'East Campus',  schoolName: 'Green Valley School', canApprove: false, canUploadBulk: false, isActive: true),
      ];
}
