import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
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
      case '/home':
        return _fade(const MainShell());
      case '/onboarding':
        return _fade(const OnboardingScreen());
      case '/group-detail':
        final args = settings.arguments as Map<String, dynamic>?;
        final groupId = args?['groupId'] as String? ?? '';
        return _fade(_GroupDetailLoader(groupId: groupId));
      default:
        return _fade(const _NotFoundScreen());
    }
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
  const _GroupDetailLoader({required this.groupId});

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
      data: (group) => GroupDetailScreen(group: group),
    );
  }
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('404 — Page not found')),
    );
  }
}
