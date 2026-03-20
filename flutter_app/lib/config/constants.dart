// ============================================================
// App Constants
// ============================================================
class AppConstants {
  AppConstants._();

  static const String appName      = 'SchoolID Pro';
  static const String appTagline   = 'Intelligent School Identity Management';
  static const String appVersion   = '1.0.0';

  // Base path for web — matches nginx location /idmgmt
  static const String basePath     = '/idmgmt';
  static const String apiBaseUrl   = '/idmgmt/api';

  // Org hierarchy levels
  static const Map<int, String> orgLevels = {
    1: 'Principal',
    2: 'Vice Principal',
    3: 'Head Teacher',
    4: 'Senior Teacher',
    5: 'Class Teacher',
    6: 'Subject Teacher',
    7: 'Backup Teacher',
    8: 'Temp Teacher',
  };

  // Status colors
  static const String statusGreen  = 'green';
  static const String statusBlue   = 'blue';
  static const String statusRed    = 'red';

  // Review statuses
  static const String reviewPending  = 'pending';
  static const String reviewSubmitted = 'parent_reviewed';
  static const String reviewApproved = 'approved';

  // Allowed attachment types
  static const List<String> allowedAttachmentTypes = ['.pdf', '.docx', '.doc', '.jpg', '.jpeg', '.png'];
  static const int maxAttachmentSizeMB = 10;
  static const int maxAttachments      = 5;
}
