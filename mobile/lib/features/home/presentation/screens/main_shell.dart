import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../groups/presentation/screens/groups_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/notifications_provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

final _navIndexProvider = StateProvider<int>((_) => 0);

/// True when user has neither payment_phone nor bank_account_number
final profileIncompleteProvider = Provider<bool>((ref) {
  final user = ref.watch(authProvider).user;
  if (user == null) return false;
  final hasPhone = (user['payment_phone'] as String?)?.isNotEmpty == true;
  final hasBank =
      (user['bank_account_number'] as String?)?.isNotEmpty == true;
  return !hasPhone && !hasBank;
});

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _screens = [
    GroupsScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(_navIndexProvider);
    final unread = ref.watch(unreadCountProvider);
    final profileIncomplete = ref.watch(profileIncompleteProvider);

    return Scaffold(
      body: IndexedStack(index: index, children: _screens),
      bottomNavigationBar: _BottomNav(
        currentIndex: index,
        unreadCount: unread,
        profileIncomplete: profileIncomplete,
        onTap: (i) => ref.read(_navIndexProvider.notifier).state = i,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final int unreadCount;
  final bool profileIncomplete;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.unreadCount,
    required this.profileIncomplete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        color: AppColors.surface,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.group_outlined,
                activeIcon: Icons.group,
                label: l.groups,
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItemWithBadge(
                icon: Icons.notifications_outlined,
                activeIcon: Icons.notifications,
                label: l.notifications,
                isActive: currentIndex == 1,
                badgeCount: unreadCount,
                onTap: () => onTap(1),
              ),
              _NavItemWithDot(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: l.profile,
                isActive: currentIndex == 2,
                showDot: profileIncomplete,
                onTap: () => onTap(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.neutral;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Profile nav item with an optional small orange dot (incomplete profile).
class _NavItemWithDot extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final bool showDot;
  final VoidCallback onTap;

  const _NavItemWithDot({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.showDot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.neutral;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isActive ? activeIcon : icon,
                      key: ValueKey(isActive),
                      color: color,
                      size: 24,
                    ),
                  ),
                  if (showDot)
                    Positioned(
                      top: -3,
                      left: -3,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.surface, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemWithBadge extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavItemWithBadge({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.neutral;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isActive ? activeIcon : icon,
                      key: ValueKey(isActive),
                      color: color,
                      size: 24,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -4,
                      left: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
