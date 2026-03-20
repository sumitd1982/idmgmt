// ============================================================
// AppShell — Responsive sidebar + bottom nav shell
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:badges/badges.dart' as badges;
import 'package:responsive_framework/responsive_framework.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';

// ── Nav Item Model ────────────────────────────────────────────
class _NavItem {
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;

  const _NavItem({
    required this.path,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge = 0,
  });
}

const _navItems = <_NavItem>[
  _NavItem(
    path: '/dashboard',
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard,
    label: 'Dashboard',
  ),
  _NavItem(
    path: '/schools',
    icon: Icons.school_outlined,
    activeIcon: Icons.school,
    label: 'Schools',
  ),
  _NavItem(
    path: '/branches',
    icon: Icons.account_tree_outlined,
    activeIcon: Icons.account_tree,
    label: 'Branches',
  ),
  _NavItem(
    path: '/org-structure',
    icon: Icons.hub_outlined,
    activeIcon: Icons.hub,
    label: 'Org Structure',
  ),
  _NavItem(
    path: '/employees',
    icon: Icons.people_outline,
    activeIcon: Icons.people,
    label: 'Employees',
  ),
  _NavItem(
    path: '/students',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    label: 'Students',
  ),
  _NavItem(
    path: '/id-templates',
    icon: Icons.badge_outlined,
    activeIcon: Icons.badge,
    label: 'ID Cards',
  ),
  _NavItem(
    path: '/reports',
    icon: Icons.bar_chart_outlined,
    activeIcon: Icons.bar_chart,
    label: 'Reports',
  ),
  _NavItem(
    path: '/requests',
    icon: Icons.inbox_outlined,
    activeIcon: Icons.inbox,
    label: 'Requests',
    badge: 3,
  ),
];

// ── Role-based nav visibility ─────────────────────────────────
List<_NavItem> _visibleNavItems(AppUser? user) {
  if (user == null) return _navItems;
  final role = user.role;
  // Super admin and school/branch admins see everything
  if (['super_admin', 'school_admin', 'branch_admin'].contains(role)) {
    return _navItems;
  }
  // Principals & VPs see most items (no Schools management)
  if (role == 'principal' || role == 'vp') {
    return _navItems
        .where((n) => n.path != '/schools')
        .toList();
  }
  // Head teachers see employees, students, reports, requests
  if (role == 'head_teacher') {
    return _navItems
        .where((n) => ['/dashboard', '/employees', '/students', '/reports', '/requests'].contains(n.path))
        .toList();
  }
  // Teachers only see students, id-templates, reports, requests
  return _navItems
      .where((n) => ['/dashboard', '/students', '/id-templates', '/reports', '/requests'].contains(n.path))
      .toList();
}

// ── Sidebar Width ─────────────────────────────────────────────
const double _sidebarExpanded  = 240.0;
const double _sidebarCollapsed = 64.0;

// ── Provider: sidebar collapsed state ─────────────────────────
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

// ============================================================
class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerOrEqualTo(MOBILE);
    final isTablet = ResponsiveBreakpoints.of(context).equals(TABLET);
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final location  = GoRouterState.of(context).matchedLocation;

    if (isMobile) {
      return _MobileShell(child: child, location: location);
    }

    final autoCollapse = isTablet;
    final effectiveCollapsed = autoCollapse ? true : collapsed;

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: Row(
        children: [
          _DesktopSidebar(
            collapsed: effectiveCollapsed,
            location:  location,
            onToggle:  autoCollapse
                ? null
                : () => ref.read(sidebarCollapsedProvider.notifier).state =
                    !collapsed,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(location: location),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Desktop Sidebar ───────────────────────────────────────────
class _DesktopSidebar extends ConsumerWidget {
  final bool collapsed;
  final String location;
  final VoidCallback? onToggle;

  const _DesktopSidebar({
    required this.collapsed,
    required this.location,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull;
    final width = collapsed ? _sidebarCollapsed : _sidebarExpanded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      width: width,
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: Color(0x44000000),
              blurRadius: 16,
              offset: Offset(4, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Logo / Brand ──────────────────────────────────
            _SidebarHeader(collapsed: collapsed, onToggle: onToggle),

            // ── Nav Items ─────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _visibleNavItems(user).length,
                itemBuilder: (ctx, i) {
                  final item    = _visibleNavItems(user)[i];
                  final isActive = location.startsWith(item.path);
                  return _SidebarNavTile(
                    item:      item,
                    isActive:  isActive,
                    collapsed: collapsed,
                    onTap:     () => ctx.go(item.path),
                  );
                },
              ),
            ),

            // ── User Footer ───────────────────────────────────
            _SidebarFooter(user: user, collapsed: collapsed, ref: ref),
          ],
        ),
      ),
    ).animate().slideX(begin: -1, duration: 400.ms, curve: Curves.easeOut);
  }
}

// ── Sidebar Header ────────────────────────────────────────────
class _SidebarHeader extends StatelessWidget {
  final bool collapsed;
  final VoidCallback? onToggle;
  const _SidebarHeader({required this.collapsed, this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.badge, color: AppTheme.primary, size: 22),
          ),
          if (!collapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppConstants.appName,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (onToggle != null)
            IconButton(
              onPressed: onToggle,
              icon: Icon(
                collapsed ? Icons.menu_open : Icons.menu,
                color: Colors.white70,
                size: 20,
              ),
              tooltip: collapsed ? 'Expand' : 'Collapse',
            ),
        ],
      ),
    );
  }
}

// ── Sidebar Nav Tile ──────────────────────────────────────────
class _SidebarNavTile extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final bool collapsed;
  final VoidCallback onTap;

  const _SidebarNavTile({
    required this.item,
    required this.isActive,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 8 : 12,
        vertical: 2,
      ),
      child: Tooltip(
        message: collapsed ? item.label : '',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              hoverColor: Colors.white.withOpacity(0.12),
              splashColor: Colors.white.withOpacity(0.2),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? 14 : 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    _buildIcon(),
                    if (!collapsed) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: GoogleFonts.poppins(
                            color: isActive
                                ? AppTheme.primary
                                : Colors.white.withOpacity(0.9),
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (item.badge > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${item.badge}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final icon = isActive ? item.activeIcon : item.icon;
    final color = isActive ? AppTheme.primary : Colors.white.withOpacity(0.9);

    if (item.badge > 0 && !isActive) {
      return badges.Badge(
        badgeContent: Text(
          '${item.badge}',
          style: const TextStyle(color: Colors.white, fontSize: 9),
        ),
        badgeStyle: const badges.BadgeStyle(badgeColor: AppTheme.accent),
        child: Icon(icon, color: color, size: 20),
      );
    }
    return Icon(icon, color: color, size: 20);
  }
}

// ── Sidebar Footer ────────────────────────────────────────────
class _SidebarFooter extends StatelessWidget {
  final AppUser? user;
  final bool collapsed;
  final WidgetRef ref;

  const _SidebarFooter({
    required this.user,
    required this.collapsed,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 8 : 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
      ),
      child: Row(
        children: [
          _buildAvatar(),
          if (!collapsed && user != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user!.displayName,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatRole(user!.role),
                      style: GoogleFonts.poppins(
                        color: AppTheme.secondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
              icon: const Icon(Icons.logout, color: Colors.white54, size: 18),
              tooltip: 'Sign out',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (user?.photoUrl != null && user!.photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(user!.photoUrl!),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppTheme.secondary.withOpacity(0.3),
      child: Text(
        user != null ? user!.displayName[0].toUpperCase() : 'U',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  String _formatRole(String role) =>
      role.replaceAll('_', ' ').split(' ')
          .map((w) => w.isEmpty
              ? ''
              : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
}

// ── Top Bar ───────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String location;
  const _TopBar({required this.location});

  String get _title {
    for (final item in _navItems) {
      if (location.startsWith(item.path)) return item.label;
    }
    return AppConstants.appName;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            _title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppTheme.grey900,
            ),
          ),
          const Spacer(),
          // Notification bell
          badges.Badge(
            badgeContent: const Text('5',
                style: TextStyle(color: Colors.white, fontSize: 9)),
            badgeStyle: const badges.BadgeStyle(badgeColor: AppTheme.accent),
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_outlined,
                  color: AppTheme.grey600),
              tooltip: 'Notifications',
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.help_outline, color: AppTheme.grey600),
            tooltip: 'Help',
          ),
        ],
      ),
    );
  }
}

// ── Mobile Shell ──────────────────────────────────────────────
class _MobileShell extends ConsumerWidget {
  final Widget child;
  final String location;
  const _MobileShell({required this.child, required this.location});

  // Only show bottom nav items for primary sections
  static const _bottomItems = [
    _NavItem(
      path: '/dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Home',
    ),
    _NavItem(
      path: '/students',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Students',
    ),
    _NavItem(
      path: '/id-templates',
      icon: Icons.badge_outlined,
      activeIcon: Icons.badge,
      label: 'ID Cards',
    ),
    _NavItem(
      path: '/reports',
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart,
      label: 'Reports',
    ),
    _NavItem(
      path: '/requests',
      icon: Icons.inbox_outlined,
      activeIcon: Icons.inbox,
      label: 'Requests',
      badge: 3,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    int currentIndex = 0;
    for (int i = 0; i < _bottomItems.length; i++) {
      if (location.startsWith(_bottomItems[i].path)) {
        currentIndex = i;
        break;
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: Text(_bottomItems[currentIndex].label),
        actions: [
          // Drawer trigger
          Builder(
            builder: (ctx) => IconButton(
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              icon: const Icon(Icons.menu),
            ),
          ),
        ],
      ),
      endDrawer: _MobileDrawer(location: location),
      body: child,
      bottomNavigationBar: _MobileBottomBar(
        items:        _bottomItems,
        currentIndex: currentIndex,
        location:     location,
      ),
    );
  }
}

class _MobileBottomBar extends StatelessWidget {
  final List<_NavItem> items;
  final int currentIndex;
  final String location;
  const _MobileBottomBar({
    required this.items,
    required this.currentIndex,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (i) {
              final item    = items[i];
              final isActive = location.startsWith(item.path);
              return Expanded(
                child: InkWell(
                  onTap: () => context.go(item.path),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      item.badge > 0
                          ? badges.Badge(
                              badgeContent: Text('${item.badge}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 9)),
                              badgeStyle: const badges.BadgeStyle(
                                  badgeColor: AppTheme.accent),
                              child: Icon(
                                isActive ? item.activeIcon : item.icon,
                                color: isActive
                                    ? AppTheme.primary
                                    : AppTheme.grey600,
                                size: 22,
                              ),
                            )
                          : Icon(
                              isActive ? item.activeIcon : item.icon,
                              color: isActive
                                  ? AppTheme.primary
                                  : AppTheme.grey600,
                              size: 22,
                            ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isActive
                              ? AppTheme.primary
                              : AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _MobileDrawer extends ConsumerWidget {
  final String location;
  const _MobileDrawer({required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user      = authState.valueOrNull;

    return Drawer(
      child: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: user?.photoUrl != null
                          ? null
                          : Text(
                              user != null
                                  ? user.displayName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 18),
                            ),
                      backgroundImage: user?.photoUrl != null
                          ? NetworkImage(user!.photoUrl!)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'User',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            user?.role ?? '',
                            style: GoogleFonts.poppins(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              // Nav items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _visibleNavItems(user).length,
                  itemBuilder: (ctx, i) {
                    final item     = _visibleNavItems(user)[i];
                    final isActive = location.startsWith(item.path);
                    return _SidebarNavTile(
                      item:      item,
                      isActive:  isActive,
                      collapsed: false,
                      onTap: () {
                        Navigator.of(context).pop();
                        ctx.go(item.path);
                      },
                    );
                  },
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white70),
                title: Text('Sign out',
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 13)),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(authNotifierProvider.notifier).signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
