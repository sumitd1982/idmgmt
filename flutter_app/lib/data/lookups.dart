// ============================================================
// Static lookup data — states, countries, subjects
// ============================================================

class Lookups {
  // ── India States ────────────────────────────────────────────
  static const List<String> indiaStates = [
    'Andaman and Nicobar Islands', 'Andhra Pradesh', 'Arunachal Pradesh',
    'Assam', 'Bihar', 'Chandigarh', 'Chhattisgarh',
    'Dadra and Nagar Haveli and Daman and Diu', 'Delhi', 'Goa', 'Gujarat',
    'Haryana', 'Himachal Pradesh', 'Jammu and Kashmir', 'Jharkhand',
    'Karnataka', 'Kerala', 'Ladakh', 'Lakshadweep', 'Madhya Pradesh',
    'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha',
    'Puducherry', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana',
    'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
  ];

  // ── Countries (common + India first) ────────────────────────
  static const List<String> countries = [
    'India', 'Afghanistan', 'Australia', 'Bangladesh', 'Bhutan', 'Canada',
    'China', 'France', 'Germany', 'Indonesia', 'Japan', 'Malaysia', 'Maldives',
    'Myanmar', 'Nepal', 'New Zealand', 'Pakistan', 'Philippines', 'Saudi Arabia',
    'Singapore', 'South Africa', 'South Korea', 'Sri Lanka', 'Thailand',
    'United Arab Emirates', 'United Kingdom', 'United States', 'Vietnam',
  ];

  // ── Subjects ────────────────────────────────────────────────
  static const List<String> subjects = [
    'Mathematics', 'Science', 'Physics', 'Chemistry', 'Biology', 'English',
    'Hindi', 'Social Studies', 'History', 'Geography', 'Civics',
    'Computer Science', 'Physical Education', 'Art & Craft', 'Music', 'Sanskrit',
    'Economics', 'Commerce', 'Accountancy', 'Business Studies',
    'Political Science', 'Psychology', 'Sociology', 'Environmental Science',
    'Moral Science',
  ];

  // ── Default class names (for seeding UI) ───────────────────
  static const List<String> defaultClasses = [
    'Nursery', 'LKG', 'UKG',
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',
  ];

  static const List<String> defaultSections = ['A', 'B', 'C', 'D', 'E'];

  // ── Permission definitions ──────────────────────────────────
  static const List<Map<String, String>> permissions = [
    {'key': 'can_send_notification_to_parent', 'label': 'Send Notifications to Parents'},
    {'key': 'can_send_request',                'label': 'Send Requests'},
    {'key': 'can_create_workflow',             'label': 'Create Workflows'},
    {'key': 'can_edit_workflow',               'label': 'Edit Workflows'},
    {'key': 'can_create_idcard',               'label': 'Create ID Card Templates'},
    {'key': 'can_modify_idcard',               'label': 'Modify ID Card Templates'},
    {'key': 'can_see_reports',                 'label': 'View Reports'},
    {'key': 'delete_employee',                 'label': 'Delete Employees'},
    {'key': 'delete_student',                  'label': 'Delete Students'},
  ];
}
