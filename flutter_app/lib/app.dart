// ============================================================
// App Router & Entry Widget
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'config/theme.dart';
import 'config/constants.dart';
import 'models/user_model.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/landing_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/school/school_list_screen.dart';
import 'screens/school/school_form_screen.dart';
import 'screens/school/branch_setup_screen.dart';
import 'screens/branch/branch_screen.dart';
import 'screens/org/org_structure_screen.dart';
import 'screens/employee/employee_screen.dart';
import 'screens/employee/employee_form_screen.dart';
import 'screens/employee/employee_bulk_upload_history_screen.dart';
import 'screens/employee/employee_bulk_upload_screen.dart';
import 'screens/student/student_screen.dart';
import 'screens/student/student_form_screen.dart';
import 'screens/student/student_bulk_upload_screen.dart';
import 'screens/id_card/id_card_designer.dart';
import 'screens/id_card/id_template_list_screen.dart';
import 'screens/id_card/id_template_designer_screen.dart';
import 'screens/parent/parent_review_screen.dart';
import 'screens/parent/parent_portal_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/requests/requests_screen.dart';
import 'screens/requests/workflow_requests_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/org/roles_screen.dart';
import 'screens/attendance/attendance_config_screen.dart';
import 'screens/attendance/take_attendance_screen.dart';
import 'screens/messaging/inbox_screen.dart';
import 'screens/messaging/chat_screen.dart';
import 'screens/settings/theme_settings_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/menu_config_screen.dart';
import 'screens/settings/dashboard_config_screen.dart';
import 'screens/settings/review_templates_screen.dart';
import 'screens/classes/class_section_screen.dart';
import 'providers/theme_provider.dart';
import 'widgets/common/app_shell.dart';

final _rootNavigatorKey   = GlobalKey<NavigatorState>();
final _shellNavigatorKey  = GlobalKey<NavigatorState>();

// Notifier that triggers GoRouter.redirect without recreating the router.
// Previously, routerProvider watched authNotifierProvider directly, which
// caused a new GoRouter to be built (starting at '/') on every auth state
// change — including the intermediate AsyncValue.loading() emitted by
// signInWithPhone — which dropped the user on the landing page instead of
// the dashboard.
class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  late AsyncValue<AppUser?> _authState;

  _RouterNotifier(this._ref) {
    _authState = _ref.read(authNotifierProvider);
    _ref.listen<AsyncValue<AppUser?>>(authNotifierProvider, (_, next) {
      _authState = next;
      notifyListeners();
    });
  }

  String? redirect(BuildContext context, GoRouterState state) {
    if (_authState.isLoading) return null;

    final isLoggedIn   = _authState.value != null;
    final isAuthPath   = state.matchedLocation.startsWith('/login') || state.matchedLocation == '/superadmin';
    final isLanding    = state.matchedLocation == '/';
    final isParentPath = state.matchedLocation.startsWith('/parent-review');
    final isOnboarding = state.matchedLocation == '/onboarding';

    if (isParentPath) return null;

    if (!isLoggedIn) {
      if (isAuthPath || isLanding) return null;
      return '/login/staff'; // Redirect to a valid sub-route
    }

    if (isAuthPath || isLanding) {
      final user = _authState.value;
      if (user != null && user.role == 'parent') return '/parent-portal';
      return '/dashboard';
    }

    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // ── Public Routes ─────────────────────────────────────
      GoRoute(
        path: '/',
        builder: (_, __) => const LandingScreen(),
      ),
      GoRoute(
        path: '/login/:type',
        builder: (_, state) => LoginScreen(portalType: state.pathParameters['type'] ?? 'staff'),
      ),
      GoRoute(
        path: '/superadmin',
        builder: (_, __) => const LoginScreen(portalType: 'superadmin'),
      ),
      GoRoute(
        path: '/parent-review',
        builder: (ctx, state) => ParentReviewScreen(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),

      // ── Authenticated Shell ───────────────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (ctx, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard',       builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/parent-portal',    builder: (_, __) => const ParentPortalScreen()),
          GoRoute(path: '/schools',         builder: (_, __) => const SchoolListScreen()),
          GoRoute(path: '/schools/new',     builder: (_, __) => const SchoolFormScreen()),
          GoRoute(
            path: '/schools/setup-branch',
            builder: (_, s) {
              final extra = (s.extra as Map<String, String>?) ?? {};
              return BranchSetupScreen(
                schoolId:      extra['schoolId']      ?? '',
                schoolName:    extra['schoolName']    ?? '',
                schoolCode:    extra['schoolCode']    ?? '',
                schoolPhone:   extra['schoolPhone']   ?? '',
                schoolEmail:   extra['schoolEmail']   ?? '',
                schoolAddress: extra['schoolAddress'] ?? '',
                schoolCity:    extra['schoolCity']    ?? '',
              );
            },
          ),
          GoRoute(
            path: '/schools/:id',
            builder: (_, s) => SchoolFormScreen(schoolId: s.pathParameters['id']),
          ),
          GoRoute(path: '/branches',        builder: (_, __) => const BranchScreen()),
          GoRoute(
            path: '/branches/class-sections',
            builder: (_, s) => ClassSectionScreen(
              branchId:   s.uri.queryParameters['branchId']   ?? '',
              branchName: s.uri.queryParameters['branchName'] ?? 'Branch',
            ),
          ),
          GoRoute(path: '/org-structure',   builder: (_, __) => const OrgStructureScreen()),
          GoRoute(path: '/employees',            builder: (_, __) => const EmployeeScreen()),
          GoRoute(path: '/employees/bulk-upload', builder: (_, __) => const EmployeeBulkUploadScreen()),
          GoRoute(path: '/employees/bulk-upload/history', builder: (_, __) => const EmployeeBulkUploadHistoryScreen()),
          GoRoute(
            path: '/employees/new',
            builder: (_, s) => EmployeeFormScreen(
              schoolId:  s.uri.queryParameters['schoolId'],
              branchId:  s.uri.queryParameters['branchId'],
              reportsTo: s.uri.queryParameters['reportsTo'],
            ),
          ),
          GoRoute(
            path: '/employees/:id',
            builder: (_, s) => EmployeeFormScreen(employeeId: s.pathParameters['id']),
          ),
          GoRoute(path: '/students',                       builder: (_, __) => const StudentScreen()),
          GoRoute(path: '/students/bulk-upload',           builder: (_, __) => const StudentBulkUploadScreen()),
          GoRoute(path: '/students/bulk-upload/history',   builder: (_, __) => const StudentBulkUploadHistoryScreen()),
          GoRoute(path: '/students/new',                   builder: (_, __) => const StudentFormScreen()),
          GoRoute(
            path: '/students/:id',
            builder: (_, s) => StudentFormScreen(studentId: s.pathParameters['id']),
          ),
          GoRoute(path: '/id-cards',        builder: (_, __) => const IdCardDesigner()),
          GoRoute(path: '/id-templates',    builder: (_, __) => const IdTemplateListScreen()),
          GoRoute(
            path: '/id-templates/new',
            builder: (_, s) => IdTemplateDesignerScreen(
              schoolId: s.uri.queryParameters['schoolId'],
            ),
          ),
          GoRoute(
            path: '/id-templates/:id',
            builder: (_, s) => IdTemplateDesignerScreen(templateId: s.pathParameters['id']),
          ),
          GoRoute(path: '/reports',         builder: (_, __) => const ReportsScreen()),
          GoRoute(path: '/requests',         builder: (_, __) => const RequestsScreen()),
          GoRoute(path: '/workflow',         builder: (_, __) => const WorkflowRequestsScreen()),
          GoRoute(path: '/roles-settings',  builder: (_, __) => const RolesSettingsScreen()),
          GoRoute(path: '/attendance-config', builder: (_, __) => const AttendanceConfigScreen()),
          GoRoute(path: '/take-attendance', builder: (_, __) => const TakeAttendanceScreen()),
          GoRoute(path: '/messaging',       builder: (_, __) => const InboxScreen()),
          GoRoute(
            path: '/messaging/:id',
            builder: (_, s) => ChatScreen(conversationId: s.pathParameters['id']!),
          ),
          GoRoute(path: '/settings',         builder: (_, __) => const SettingsScreen()),
          GoRoute(path: '/settings/theme',   builder: (_, __) => const ThemeSettingsScreen()),
          GoRoute(path: '/settings/menu-layout',
            builder: (_, __) => const MenuConfigScreen()),
          GoRoute(path: '/settings/dashboard-widgets',
            builder: (_, __) => const DashboardConfigScreen()),
          GoRoute(path: '/settings/review-templates',
            builder: (_, state) => ReviewTemplatesScreen(
              entityType: state.uri.queryParameters['type'] ?? 'student',
            )),
        ],
      ),
    ],
    errorBuilder: (ctx, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: 16),
            Text('Page not found: ${state.error}',
                style: const TextStyle(color: AppTheme.grey600)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ctx.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

class IdMgmtApp extends ConsumerWidget {
  const IdMgmtApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final theme  = ref.watch(themeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light.copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.primaryColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: theme.portalTheme.bodyColor,
        appBarTheme: AppTheme.light.appBarTheme.copyWith(
          backgroundColor: theme.portalTheme.headerColor,
          foregroundColor: theme.portalTheme.menuTextColor,
        ),
      ),
      darkTheme: AppTheme.dark.copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.primaryColor,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: theme.portalTheme.isDark ? ThemeMode.dark : theme.mode,
      routerConfig: router,
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: [
          const Breakpoint(start: 0,    end: 450,  name: MOBILE),
          const Breakpoint(start: 451,  end: 800,  name: TABLET),
          const Breakpoint(start: 801,  end: 1200, name: DESKTOP),
          const Breakpoint(start: 1201, end: 2460, name: '4K'),
        ],
      ),
    );
  }
}
