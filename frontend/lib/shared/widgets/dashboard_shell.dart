import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme_provider.dart';
import '../theme/app_design_system.dart';
import '../../core/providers/auth_provider.dart';

class DashboardShell extends ConsumerStatefulWidget {
  final Widget child;

  const DashboardShell({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _getSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/live')) return 1;
    if (location.startsWith('/standings')) return 2;
    if (location.startsWith('/predictor')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/live');
        break;
      case 2:
        context.go('/standings');
        break;
      case 3:
        context.go('/predictor');
        break;
      case 4:
        _scaffoldKey.currentState!.openDrawer();
        break;
    }
  }

  Widget _buildMoreDrawer(BuildContext context) {
    final authState = ref.read(authProvider);
    final themeState = ref.read(themeProvider);
    final accentColor = themeState.selectedTeam.primaryColor;

    final items = [
      _DrawerItem(icon: Icons.psychology_rounded, label: 'APEX AI', sublabel: 'Chief Strategist v1.5', route: '/chat', color: DS.orange),
      _DrawerItem(icon: Icons.archive_outlined, label: 'F1 ARCHIVE', sublabel: 'History 2010–2026', route: '/history', color: DS.teal),
      _DrawerItem(icon: Icons.tune_rounded, label: 'PIT LANE', sublabel: 'Settings & Profile', route: '/settings', color: DS.textMuted),
    ];

    return Drawer(
      width: 280,
      backgroundColor: DS.surface0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: DS.outline)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 36,
                    decoration: BoxDecoration(
                      color: DS.red,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('APEX', style: DS.driverCode(size: 14, color: DS.textPrimary)),
                          const SizedBox(width: 4),
                          DSWidgets.redBadge('F1', size: 9),
                        ],
                      ),
                      Text('MORE OPTIONS', style: DS.labelCaps(size: 8, color: DS.textMuted)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close, size: 18, color: DS.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Menu items with connecting line (UX Law 5 — Connectedness)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Connecting vertical line through icon column
                          Padding(
                            padding: const EdgeInsets.only(top: 20, left: 23),
                            child: Container(
                              width: 1,
                              color: DS.outline,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: items.map((item) {
                                return _buildDrawerMenuItem(context, item);
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // Sign out at bottom
                    Container(
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: DS.outline)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: GestureDetector(
                          onTap: () async {
                            Navigator.of(context).pop();
                            await ref.read(authProvider.notifier).logout();
                            if (context.mounted) context.go('/onboarding');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: DS.red.withValues(alpha: 0.08),
                              borderRadius: DS.aeroCornerSm,
                              border: Border.all(color: DS.red.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 8),
                                Icon(Icons.logout_rounded, size: 18, color: DS.red),
                                const SizedBox(width: 12),
                                Text('SIGN OUT', style: DS.labelCaps(size: 10, color: DS.red)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // User info footer
                    if (authState.name != null) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                authState.name![0].toUpperCase(),
                                style: DS.labelCaps(size: 10, color: accentColor),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(authState.name!, style: DS.body(size: 11, color: DS.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(authState.email ?? '', style: DS.labelCaps(size: 8, color: DS.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerMenuItem(BuildContext context, _DrawerItem item) {
    final location = GoRouterState.of(context).uri.toString();
    final isActive = location.startsWith(item.route);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        context.go(item.route);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4, left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? item.color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: DS.aeroCornerSm,
          border: isActive ? Border.all(color: item.color.withValues(alpha: 0.3)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.15),
                borderRadius: DS.aeroCornerSm,
              ),
              child: Icon(item.icon, size: 16, color: item.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label, style: DS.labelCaps(size: 10, color: isActive ? item.color : DS.textPrimary)),
                  const SizedBox(height: 2),
                  Text(item.sublabel, style: DS.labelCaps(size: 8, color: DS.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 14, color: DS.textMuted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final accentColor = themeState.selectedTeam.primaryColor;
    final selectedIndex = _getSelectedIndex(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: DS.bg,
      drawer: _buildMoreDrawer(context),
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: DS.surface0,
          border: Border(
            top: BorderSide(color: DS.outline, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                _buildNavItem(
                  context: context, index: 0, currentIndex: selectedIndex,
                  label: 'PITWALL', icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded, accentColor: accentColor,
                ),
                _buildNavItem(
                  context: context, index: 1, currentIndex: selectedIndex,
                  label: 'TIMING', icon: Icons.timer_outlined,
                  activeIcon: Icons.timer_rounded, accentColor: accentColor,
                ),
                _buildNavItem(
                  context: context, index: 2, currentIndex: selectedIndex,
                  label: 'STANDINGS', icon: Icons.emoji_events_outlined,
                  activeIcon: Icons.emoji_events_rounded, accentColor: accentColor,
                ),
                _buildNavItem(
                  context: context, index: 3, currentIndex: selectedIndex,
                  label: 'PREDICT', icon: Icons.gps_fixed_outlined,
                  activeIcon: Icons.gps_fixed_rounded, accentColor: accentColor,
                ),
                _buildNavItem(
                  context: context, index: 4, currentIndex: selectedIndex,
                  label: 'MORE', icon: Icons.menu_rounded,
                  activeIcon: Icons.menu_open_rounded, accentColor: accentColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required int currentIndex,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required Color accentColor,
  }) {
    final isSelected = index == currentIndex;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index, context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 24 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 4),
            Icon(
              isSelected ? activeIcon : icon,
              size: 20,
              color: isSelected ? accentColor : DS.textMuted,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: DS.labelCaps(
                size: 7.5,
                color: isSelected ? DS.textPrimary : DS.textMuted,
              ).copyWith(
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem {
  final IconData icon;
  final String label;
  final String sublabel;
  final String route;
  final Color color;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.route,
    required this.color,
  });
}
