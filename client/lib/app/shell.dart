import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../features/auth/state/auth_notifier.dart';
import '../features/notifications/widgets/notification_drawer.dart';
import '../shared/api/api_client.dart';
import '../shared/theme/colors.dart';
import '../shared/theme/spacing.dart';

final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

class AppShell extends ConsumerWidget {
  final Widget child;
  final String location;

  const AppShell({
    super.key,
    required this.child,
    required this.location,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final isCollapsed = ref.watch(sidebarCollapsedProvider);
    final user = authState.user;
    final isStaff = user?.role.isStaff ?? false;
    final isManagement = user?.role.isManagement ?? false;
    final isAdmin = user?.role.isAdmin ?? false;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < AppSpacing.breakpointMobile;

    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    final List<_NavItem> navItems = [
      const _NavItem(
        path: '/dashboard',
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        section: 'OVERVIEW',
      ),
      const _NavItem(
        path: '/cases',
        label: 'Cases / Workspaces',
        icon: Icons.inbox_outlined,
        selectedIcon: Icons.inbox,
        section: 'OPERATIONS',
      ),
      if (!isStaff)
        const _NavItem(
          path: '/cases/new',
          label: '+ Report Incident',
          icon: Icons.add_circle_outline,
          selectedIcon: Icons.add_circle,
          section: 'OPERATIONS',
          isHighlight: true,
        ),
      if (isManagement)
        const _NavItem(
          path: '/reports',
          label: 'Executive Analytics',
          icon: Icons.insights_outlined,
          selectedIcon: Icons.insights,
          section: 'INSIGHTS & ASSETS',
        ),
      if (isAdmin)
        const _NavItem(
          path: '/admin',
          label: 'System Health & Sweeps',
          icon: Icons.monitor_heart_outlined,
          selectedIcon: Icons.monitor_heart,
          section: 'GOVERNANCE',
        ),
    ];

    int selectedIndex = 0;
    for (int i = 0; i < navItems.length; i++) {
      final navPath = navItems[i].path;
      if (location == navPath ||
          (navPath != '/dashboard' && navPath != '/cases/new' && location.startsWith(navPath))) {
        selectedIndex = i;
      }
    }

    Widget buildDrawerContent() {
      return Container(
        width: 280,
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand Header
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Text(
                    'AsistIQ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: -0.3,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'v1.0.0',
                      style: TextStyle(fontSize: 10, fontFamily: 'JetBrains Mono', color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Text(
                      user?.role.toDisplayString() ?? 'User',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF4338CA), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                children: [
                  _buildSectionHeader('OVERVIEW'),
                  _buildSidebarItem(
                    context,
                    icon: Icons.dashboard_outlined,
                    selectedIcon: Icons.dashboard,
                    label: 'Dashboard',
                    isSelected: location == '/dashboard' || location == '/',
                    onTap: () {
                      if (isMobile && Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                      context.go('/dashboard');
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildSectionHeader('OPERATIONS'),
                  _buildSidebarItem(
                    context,
                    icon: Icons.inbox_outlined,
                    selectedIcon: Icons.inbox,
                    label: 'Cases / Workspaces',
                    isSelected: location.startsWith('/cases') && location != '/cases/new',
                    onTap: () {
                      if (isMobile && Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                      context.go('/cases');
                    },
                  ),
                  _buildSidebarItem(
                    context,
                    icon: Icons.add_circle_outline,
                    selectedIcon: Icons.add_circle,
                    label: '+ Report Incident',
                    isSelected: location == '/cases/new',
                    isHighlight: true,
                    onTap: () {
                      if (isMobile && Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                      context.go('/cases/new');
                    },
                  ),
                  const SizedBox(height: 16),

                  if (isManagement) ...[
                    _buildSectionHeader('INSIGHTS & ASSETS'),
                    _buildSidebarItem(
                      context,
                      icon: Icons.insights_outlined,
                      selectedIcon: Icons.insights,
                      label: 'Executive Analytics',
                      isSelected: location.startsWith('/reports'),
                      onTap: () {
                        if (isMobile && Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                        context.go('/reports');
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (isAdmin) ...[
                    _buildSectionHeader('GOVERNANCE'),
                    _buildSidebarItem(
                      context,
                      icon: Icons.monitor_heart_outlined,
                      selectedIcon: Icons.monitor_heart,
                      label: 'System Health & Sweeps',
                      isSelected: location.startsWith('/admin'),
                      onTap: () {
                        if (isMobile && Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                        context.go('/admin');
                      },
                    ),
                    _buildSidebarItem(
                      context,
                      icon: Icons.policy_outlined,
                      selectedIcon: Icons.policy,
                      label: 'Security Audit Trail',
                      isSelected: false,
                      onTap: () {
                        if (isMobile && Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                        context.go('/admin');
                      },
                    ),
                  ],
                ],
              ),
            ),

            // Profile Footer
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: Center(
                          child: Text(
                            ((user?.fullName.isNotEmpty ?? false)
                                ? user!.fullName.substring(0, 1).toUpperCase()
                                : (user?.email.isNotEmpty ?? false
                                    ? user!.email.substring(0, 1).toUpperCase()
                                    : 'U')),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4338CA), fontSize: 14),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Anonymous',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontFamily: 'JetBrains Mono'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, size: 18, color: Color(0xFF94A3B8)),
                    tooltip: 'Logout',
                    onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isMobile) {
      // Mobile Layout with Hamburger Menu Drawer
      return Scaffold(
        key: scaffoldKey,
        drawer: Drawer(child: buildDrawerContent()),
        endDrawer: const NotificationDrawer(),
        appBar: AppBar(
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF334155)),
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'AsistIQ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'v1.0.0',
                  style: TextStyle(fontSize: 10, fontFamily: 'JetBrains Mono', color: AppColors.primary),
                ),
              ),
            ],
          ),
          actions: [
            _buildDownloadAppsMenu(context),
            Builder(
              builder: (ctx) => IconButton(
                icon: const Badge(
                  label: Text('3', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  child: Icon(Icons.notifications_outlined),
                ),
                tooltip: 'Notifications',
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.textMutedLight),
              tooltip: 'Logout',
              onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
            ),
          ],
        ),
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex.clamp(0, navItems.length - 1),
          onDestinationSelected: (idx) => context.go(navItems[idx].path),
          destinations: navItems
              .map(
                (item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: item.label,
                ),
              )
              .toList(),
        ),
      );
    }

    // Desktop / Tablet Layout with Collapsible Hamburger Sidebar
    final sidebarWidth = isCollapsed ? 68.0 : 260.0;

    return Scaffold(
      endDrawer: const NotificationDrawer(),
      body: Row(
        children: [
          // Sidebar (Collapsible 260px / 68px)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: sidebarWidth,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: isCollapsed
                ? _buildCollapsedRail(context, ref, user, location, isManagement, isAdmin)
                : buildDrawerContent(),
          ),

          // Main Content View & Global Topbar
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                Container(
                  height: 64,
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth < 1024 ? AppSpacing.md : AppSpacing.lg,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      // Hamburger Toggle Button
                      IconButton(
                        icon: Icon(
                          isCollapsed ? Icons.menu : Icons.menu_open,
                          color: const Color(0xFF475569),
                        ),
                        tooltip: isCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
                        onPressed: () {
                          ref.read(sidebarCollapsedProvider.notifier).state = !isCollapsed;
                        },
                      ),
                      const SizedBox(width: AppSpacing.xs),

                      // Search Bar with Ctrl+K
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 420),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  screenWidth < 900 ? 'Search incidents...' : 'Search incidents, runbooks, telemetry...',
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (screenWidth >= 900)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: const Text(
                                    'Ctrl+K',
                                    style: TextStyle(fontSize: 10, fontFamily: 'JetBrains Mono', color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),

                      // APScheduler Sweep Status Badge (Adaptive)
                      if (screenWidth >= 1000) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Color(0xFF10B981), size: 7),
                              SizedBox(width: 6),
                              Text(
                                'APScheduler: Active',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF047857), fontFamily: 'JetBrains Mono'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ] else if (screenWidth >= 768) ...[
                        Tooltip(
                          message: 'APScheduler: Active (24/7 SLA Sweep Engine)',
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: const Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],

                      // Download Apps Dropdown Menu
                      _buildDownloadAppsMenu(context),
                      const SizedBox(width: AppSpacing.xs),

                      // Notifications Icon
                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Badge(
                            label: Text('3', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            child: Icon(Icons.notifications_outlined, color: Color(0xFF475569)),
                          ),
                          tooltip: 'Notifications Inbox',
                          onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),

                      // New Incident CTA
                      if (screenWidth >= 800)
                        ElevatedButton.icon(
                          onPressed: () => context.go('/cases/new'),
                          icon: const Icon(Icons.bolt, size: 16),
                          label: const Text('+ Report Incident', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Color(0xFF4F46E5)),
                          tooltip: 'Report Incident',
                          onPressed: () => context.go('/cases/new'),
                        ),
                    ],
                  ),
                ),

                // Active Route Content
                Expanded(
                  child: Material(
                    color: const Color(0xFFF8FAFC),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadAppsMenu(BuildContext context) {
    final baseUrl = ApiClient.defaultBaseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
    final androidUrl = '$baseUrl/api/v1/releases/android';
    final windowsUrl = '$baseUrl/api/v1/releases/windows';

    return PopupMenuButton<String>(
      tooltip: 'Download Desktop & Mobile Apps',
      icon: const Icon(Icons.download_for_offline_outlined, color: Color(0xFF475569)),
      onSelected: (val) async {
        final urlString = val == 'android' ? androidUrl : windowsUrl;
        final uri = Uri.parse(urlString);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not launch download URL: $urlString')),
            );
          }
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'windows',
          child: Row(
            children: [
              Icon(Icons.desktop_windows, size: 18, color: Color(0xFF4F46E5)),
              SizedBox(width: 10),
              Text('Windows Setup (.exe)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'android',
          child: Row(
            children: [
              Icon(Icons.android, size: 18, color: Color(0xFF10B981)),
              SizedBox(width: 10),
              Text('Android APK (.apk)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedRail(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    String location,
    bool isManagement,
    bool isAdmin,
  ) {
    return Column(
      children: [
        // Brand Icon Header
        Container(
          height: 64,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
            ),
          ),
        ),

        // Collapsed Nav Icons
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              _buildCollapsedIconItem(
                context,
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard,
                tooltip: 'OVERVIEW: Dashboard',
                isSelected: location == '/dashboard' || location == '/',
                onTap: () => context.go('/dashboard'),
              ),
              const SizedBox(height: 8),
              _buildCollapsedIconItem(
                context,
                icon: Icons.inbox_outlined,
                selectedIcon: Icons.inbox,
                tooltip: 'OPERATIONS: Cases / Workspaces',
                isSelected: location.startsWith('/cases') && location != '/cases/new',
                onTap: () => context.go('/cases'),
              ),
              const SizedBox(height: 8),
              _buildCollapsedIconItem(
                context,
                icon: Icons.add_circle_outline,
                selectedIcon: Icons.add_circle,
                tooltip: 'OPERATIONS: + Report Incident',
                isSelected: location == '/cases/new',
                isHighlight: true,
                onTap: () => context.go('/cases/new'),
              ),
              if (isManagement) ...[
                const SizedBox(height: 16),
                _buildCollapsedIconItem(
                  context,
                  icon: Icons.insights_outlined,
                  selectedIcon: Icons.insights,
                  tooltip: 'INSIGHTS & ASSETS: Executive Analytics',
                  isSelected: location.startsWith('/reports'),
                  onTap: () => context.go('/reports'),
                ),
              ],
              if (isAdmin) ...[
                const SizedBox(height: 16),
                _buildCollapsedIconItem(
                  context,
                  icon: Icons.monitor_heart_outlined,
                  selectedIcon: Icons.monitor_heart,
                  tooltip: 'GOVERNANCE: System Health & Sweeps',
                  isSelected: location.startsWith('/admin'),
                  onTap: () => context.go('/admin'),
                ),
              ],
            ],
          ),
        ),

        // User Avatar Logout
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: IconButton(
            icon: const Icon(Icons.logout, size: 20, color: Color(0xFF94A3B8)),
            tooltip: 'Logout',
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedIconItem(
    BuildContext context, {
    required IconData icon,
    required IconData selectedIcon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    return Center(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFEEF2FF)
                  : (isHighlight ? const Color(0xFFF8FAFC) : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: const Color(0xFFC7D2FE))
                  : (isHighlight ? Border.all(color: const Color(0xFFE2E8F0)) : null),
            ),
            child: Icon(
              isSelected ? selectedIcon : icon,
              size: 20,
              color: isSelected
                  ? const Color(0xFF4338CA)
                  : (isHighlight ? const Color(0xFF4F46E5) : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 6, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context, {
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFEEF2FF)
                  : (isHighlight ? const Color(0xFFF8FAFC) : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: const Color(0xFFC7D2FE))
                  : (isHighlight ? Border.all(color: const Color(0xFFE2E8F0)) : null),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: 18,
                  color: isSelected
                      ? const Color(0xFF4338CA)
                      : (isHighlight ? const Color(0xFF4F46E5) : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF4338CA)
                          : (isHighlight ? const Color(0xFF4338CA) : const Color(0xFF334155)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String section;
  final bool isHighlight;

  const _NavItem({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.section = 'OPERATIONS',
    this.isHighlight = false,
  });
}
