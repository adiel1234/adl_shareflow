import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/home/presentation/screens/main_shell.dart';
import '../../features/groups/presentation/screens/group_detail_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../providers/groups_provider.dart';

class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return _fade(const SplashScreen());
      case '/login':
        return _slide(const LoginScreen());
      case '/register':
        return _slide(const RegisterScreen());
      case '/forgot-password':
        return _slide(const ForgotPasswordScreen());
      case '/home':
        return _fade(const MainShell());
      case '/onboarding':
        return _fade(const OnboardingScreen());
      case '/group-detail':
        final args = settings.arguments as Map<String, dynamic>?;
        final groupId = args?['groupId'] as String? ?? '';
        final initialTab = args?['initialTab'] as int? ?? 0;
        final openInvite = args?['openInvite'] as bool? ?? false;
        final forceCoach = args?['forceCoach'] as bool? ?? false;
        final popOnCoachEnd = args?['popOnCoachEnd'] as bool? ?? false;
        return _fade(_GroupDetailLoader(
          groupId: groupId,
          initialTabIndex: initialTab,
          openInviteOnStart: openInvite,
          forceCoach: forceCoach,
          popOnCoachEnd: popOnCoachEnd,
        ));
      default:
        // Invite deep links (/join/<code>, shareflow://join/...) are handled by
        // app_links → pendingInviteCodeProvider. Never show the 404 screen.
        final name = settings.name ?? '';
        if (isJoinDeepLinkRoute(name)) {
          return _fade(const SplashScreen());
        }
        return _fade(const _NotFoundScreen());
    }
  }

  /// True for Navigator routes that come from invite deep links.
  @visibleForTesting
  static bool isJoinDeepLinkRoute(String name) {
    final normalized = name.startsWith('/') ? name.substring(1) : name;
    return normalized == 'join' ||
        normalized.startsWith('join/') ||
        name.contains('/join/');
  }

  static PageRouteBuilder _fade(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      );

  static PageRouteBuilder _slide(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeInOut)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      );
}

/// Loads a group by ID from the API and shows GroupDetailScreen.
class _GroupDetailLoader extends ConsumerWidget {
  final String groupId;
  final int initialTabIndex;
  final bool openInviteOnStart;
  final bool forceCoach;
  final bool popOnCoachEnd;
  const _GroupDetailLoader({
    required this.groupId,
    this.initialTabIndex = 0,
    this.openInviteOnStart = false,
    this.forceCoach = false,
    this.popOnCoachEnd = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupDetailProvider(groupId));
    return groupAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('Could not load group')),
      ),
      data: (group) => GroupDetailScreen(
        group: group,
        initialTabIndex: initialTabIndex,
        openInviteOnStart: openInviteOnStart,
        forceCoach: forceCoach,
        popOnCoachEnd: popOnCoachEnd,
      ),
    );
  }
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('404: Page not found')),
    );
  }
}
