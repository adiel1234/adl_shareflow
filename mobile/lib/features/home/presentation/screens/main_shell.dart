import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../groups/presentation/screens/groups_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/groups_provider.dart';
import '../../../../providers/notifications_provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/home_coach.dart';
import '../widgets/home_howto.dart';

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

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final _scanKey = GlobalKey();
  final _joinKey = GlobalKey();
  final _createKey = GlobalKey();
  final _notifKey = GlobalKey();
  final _profileKey = GlobalKey();
  bool _coachStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeScreenshotNavigate();
      await _maybeShowCoach();
    });
  }

  /// Store-prep screenshots: skip coach and open a target screen.
  Future<void> _maybeScreenshotNavigate() async {
    const scene = String.fromEnvironment('SCREENSHOT_SCENE');
    const groupId = String.fromEnvironment('SCREENSHOT_GROUP_ID');
    if (scene.isEmpty) return;
    _coachStarted = true; // suppress coach overlays
    if (scene == 'home' || groupId.isEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final initialTab = scene == 'balances' ? 1 : 0;
    final openInvite = scene == 'invite';
    Navigator.pushNamed(
      context,
      '/group-detail',
      arguments: <String, dynamic>{
        'groupId': groupId,
        'initialTab': initialTab,
        'openInvite': openInvite,
        'forceCoach': false,
      },
    );
  }

  List<CoachTarget> _homeCoachTargets(AppLocalizations l) => [
        CoachTarget(
          key: _createKey,
          title: l.coachCreateGroupTitle,
          body: l.coachCreateGroupBody,
        ),
        CoachTarget(
          key: _joinKey,
          title: l.coachJoinGroupTitle,
          body: l.coachJoinGroupBody,
        ),
        CoachTarget(
          key: _scanKey,
          title: l.coachScanQrTitle,
          body: l.coachScanQrBody,
        ),
        CoachTarget(
          key: _notifKey,
          title: l.coachNotificationsTitle,
          body: l.coachNotificationsBody,
        ),
        CoachTarget(
          key: _profileKey,
          title: l.coachProfileTitle,
          body: l.coachProfileBody,
        ),
      ];

  Future<void> _openGroupButtonTour({
    required bool force,
    required int stepOffset,
    required int totalSteps,
  }) async {
    if (!mounted) return;
    try {
      final groups = await ref.read(groupsProvider.future);
      final operational = groups.where((g) => g.isOperational && !g.isClosed);
      if (operational.isEmpty || !mounted) return;
      final group = operational.first;
      await Navigator.of(context).pushNamed(
        '/group-detail',
        arguments: {
          'groupId': group.id,
          'forceCoach': force,
          'popOnCoachEnd': true,
          'coachStepOffset': stepOffset,
          'coachTotalSteps': totalSteps,
        },
      );
    } catch (_) {
      // No groups loaded — skip group tour.
    }
  }

  Future<void> _replayTour() async {
    if (!mounted) return;
    ref.read(_navIndexProvider.notifier).state = 0;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    const total = kUnifiedCoachTotalSteps;
    await showHomeCoach(
      context,
      targets: _homeCoachTargets(l),
      stepOffset: 0,
      totalSteps: total,
      markDone: true,
    );
    if (!mounted) return;
    await _openGroupButtonTour(
      force: true,
      stepOffset: kUnifiedCoachHomeSteps,
      totalSteps: total,
    );
  }

  void _showHelpHintSnack() {
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.homeHelpAfterTour),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _maybeShowCoach() async {
    if (_coachStarted || !mounted) return;
    _coachStarted = true;
    const screenshotScene = String.fromEnvironment('SCREENSHOT_SCENE');
    if (screenshotScene.isNotEmpty) return;

    var showedTour = false;

    if (!await isHomeCoachDone()) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      showedTour = true;
      const total = kUnifiedCoachTotalSteps;
      await showHomeCoach(
        context,
        targets: _homeCoachTargets(l),
        stepOffset: 0,
        totalSteps: total,
      );
      if (!mounted) return;
      await _openGroupButtonTour(
        force: false,
        stepOffset: kUnifiedCoachHomeSteps,
        totalSteps: total,
      );
    }

    if (!mounted) return;
    if (!await isHomeHowToDone()) {
      if (!mounted) return;
      showedTour = true;
      await showHomeHowTo(context);
    }

    if (showedTour && mounted) {
      _showHelpHintSnack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(_navIndexProvider);
    final unread = ref.watch(unreadCountProvider);
    final profileIncomplete = ref.watch(profileIncompleteProvider);

    final screens = [
      GroupsScreen(
        coachScanKey: _scanKey,
        coachJoinKey: _joinKey,
        coachCreateKey: _createKey,
      ),
      const NotificationsScreen(),
      ProfileScreen(
        onReplayTour: _replayTour,
      ),
    ];

    return Scaffold(
      // Keep body above the bottom nav; avoid edge-to-edge overlap on Android.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: index, children: screens),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: index,
        unreadCount: unread,
        profileIncomplete: profileIncomplete,
        notifKey: _notifKey,
        profileKey: _profileKey,
        onTap: (i) => ref.read(_navIndexProvider.notifier).state = i,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final int unreadCount;
  final bool profileIncomplete;
  final GlobalKey notifKey;
  final GlobalKey profileKey;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.unreadCount,
    required this.profileIncomplete,
    required this.notifKey,
    required this.profileKey,
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
                key: notifKey,
                icon: Icons.notifications_outlined,
                activeIcon: Icons.notifications,
                label: l.notifications,
                isActive: currentIndex == 1,
                badgeCount: unreadCount,
                onTap: () => onTap(1),
              ),
              _NavItemWithDot(
                key: profileKey,
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
    super.key,
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
    super.key,
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
