import 'package:adl_shareflow/core/config/router.dart';
import 'package:adl_shareflow/features/auth/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('invite deep link routes', () {
    test('detects join paths from Flutter built-in deep linking', () {
      expect(AppRouter.isJoinDeepLinkRoute('/join/ABC123'), isTrue);
      expect(AppRouter.isJoinDeepLinkRoute('join/ABC123'), isTrue);
      expect(AppRouter.isJoinDeepLinkRoute('/join'), isTrue);
      expect(AppRouter.isJoinDeepLinkRoute('/home'), isFalse);
      expect(AppRouter.isJoinDeepLinkRoute('/unknown'), isFalse);
    });

    testWidgets('does not show 404 for /join/<code>', (tester) async {
      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: '/join/ABC123'),
      );
      expect(route, isNotNull);

      late Widget page;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                page = (route as PageRouteBuilder).pageBuilder(
                  context,
                  const AlwaysStoppedAnimation(1),
                  const AlwaysStoppedAnimation(1),
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(page, isA<SplashScreen>());
      expect(find.text('404: Page not found'), findsNothing);
    });

    testWidgets('still shows 404 for unknown non-join routes', (tester) async {
      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: '/totally-missing'),
      );
      expect(route, isNotNull);

      late Widget page;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              page = (route as PageRouteBuilder).pageBuilder(
                context,
                const AlwaysStoppedAnimation(1),
                const AlwaysStoppedAnimation(1),
              );
              return page;
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('404: Page not found'), findsOneWidget);
    });
  });
}
