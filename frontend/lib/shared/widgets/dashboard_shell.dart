import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme_provider.dart';
import '../theme/app_design_system.dart';

class DashboardShell extends ConsumerWidget {
  final Widget child;

  const DashboardShell({
    super.key,
    required this.child,
  });

  int _getSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/live')) return 1;
    if (location.startsWith('/standings')) return 2;
    if (location.startsWith('/predictor')) return 3;
    if (location.startsWith('/chat')) return 4;
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
        context.go('/chat');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final accentColor = themeState.selectedTeam.primaryColor;
    final selectedIndex = _getSelectedIndex(context);

    return Scaffold(
      backgroundColor: DS.bg,
      body: child,
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
                  label: 'APEX AI', icon: Icons.psychology_outlined,
                  activeIcon: Icons.psychology_rounded, accentColor: accentColor,
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
            // Top accent pill
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
