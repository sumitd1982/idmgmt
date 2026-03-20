// ============================================================
// App Router & Entry Widget
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'config/theme.dart';
import 'config/constants.dart';
import 'providers/auth_provider.dart';
import 'screens/landing/landing_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/school/school_list_screen.dart';
import 'screens/school/school_form_screen.dart';
import 'screens/branch/branch_screen.dart';
import 'screens/org/org_structure_screen.dart';
import 'screens/employee/employee_screen.dart';
import 'screens/student/student_screen.dart';
import 'screens/student/student_form_screen.dart';
import 'screens/id_card/id_card_designer.dart';
import 'screens/id_card/id_template_list_screen.dart';
import 'screens/id_card/id_template_designer_screen.dart';
import 'screens/parent/parent_review_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/requests/requests_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'widgets/common/app_shell.dart';

final _rootNavigatorKey   = GlobalKey<NavigatorState>();
final _shellNavigatorKey  = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      // Still loading — don't redirect yet
      if (authNotifier.isLoading) return null;

      final isLoggedIn   = authNotifier.value != null;
      final isAuthPath   = state.matchedLocation == '/login';
      final isPublicPath = state.matchedLocation == '/' ||
                           state.matchedLocation.startsWith('/parent-review');
      final isOnboarding = state.matchedLocation == '/onboarding';

      if (!isLoggedIn && !isPublicPath && !isAuthPath) return '/login';
      if (isLoggedIn  && isAuthPath)   return '/dashboard';

      // Super admins who need onboarding → redirect to /onboarding
      final user = authNotifier.value;
      if (isLoggedIn && !isOnboarding && !isPublicPath &&
          user?.needsOnboarding == true) {
        return '/onboarding';
      }
      return null;
    },
    routes: [
      // ── Public Routes ─────────────────────────────────────
      GoRoute(
        path: '/',
        builder: (_, __) => const LandingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
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
          GoRoute(path: '/schools',         builder: (_, __) => const SchoolListScreen()),
          GoRoute(path: '/schools/new',     builder: (_, __) => const SchoolFormScreen()),
          GoRoute(
            path: '/schools/:id',
            builder: (_, s) => SchoolFormScreen(schoolId: s.pathParameters['id']),
          ),
          GoRoute(path: '/branches',        builder: (_, __) => const BranchScreen()),
          GoRoute(path: '/org-structure',   builder: (_, __) => const OrgStructureScreen()),
          GoRoute(path: '/employees',       builder: (_, __) => const EmployeeScreen()),
          GoRoute(path: '/students',        builder: (_, __) => const StudentScreen()),
          GoRoute(path: '/students/new',    builder: (_, __) => const StudentFormScreen()),
          GoRoute(
            path: '/students/:id',
            builder: (_, s) => StudentFormScreen(studentId: s.pathParameters['id']),
          ),
          GoRoute(path: '/id-cards',        builder: (_, __) => const IdCardDesigner()),
          GoRoute(path: '/id-templates',    builder: (_, __) => const IdTemplateListScreen()),
          GoRoute(path: '/id-templates/new', builder: (_, __) => const IdTemplateDesignerScreen()),
          GoRoute(
            path: '/id-templates/:id',
            builder: (_, s) => IdTemplateDesignerScreen(templateId: s.pathParameters['id']),
          ),
          GoRoute(path: '/reports',         builder: (_, __) => const ReportsScreen()),
          GoRoute(path: '/requests',        builder: (_, __) => const RequestsScreen()),
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

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
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
