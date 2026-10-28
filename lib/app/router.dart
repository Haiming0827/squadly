import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/account_contacts_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/password_recovery_screen.dart';
import '../features/auth/presentation/screens/password_setup_screen.dart';
import '../features/conversation/presentation/offline_conversations_screen.dart';
import '../features/finance/presentation/screens/finance_screen.dart';
import '../features/fitness/presentation/screens/fitness_screen.dart';
import '../features/food/presentation/screens/food_screen.dart';
import '../features/home/presentation/screens/home_shell_screen.dart';
import '../features/home/presentation/screens/remote_home_shell_screen.dart';
import '../features/photo_widget/domain/photo_widget.dart';
import '../features/photo_widget/presentation/photo_widget_entry_screen.dart';
import '../features/photos/presentation/photo_composer_screen.dart';
import '../features/squad/presentation/screens/invitation_landing_screen.dart';
import '../features/travel/presentation/screens/travel_screen.dart';

part 'router.g.dart';

/// Only a local invitation path may survive the authentication detour.
String invitationReturnPath(String? from) {
  if (from == null) return '/';
  final uri = Uri.tryParse(from);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.pathSegments.length != 2 ||
      uri.pathSegments.first != 'invite' ||
      uri.pathSegments.last.isEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return '/';
  }
  return uri.toString();
}

const photoWidgetUrlScheme = String.fromEnvironment(
  'SQUADLY_WIDGET_URL_SCHEME',
  defaultValue: 'squadly',
);

/// Only validated local invitation and fixed widget paths survive login.
String authenticationReturnPath(String? from) {
  if (from == null) return '/';
  final widget = parsePhotoWidgetEntry(from, scheme: photoWidgetUrlScheme);
  if (widget != null) return photoWidgetReturnPath(widget);
  return invitationReturnPath(from);
}

@riverpod
GoRouter router(Ref ref) {
  final authRefresh = ValueNotifier(0);
  final sessionNavigation = _SessionNavigationObserver();
  var disposed = false;
  var resetScheduled = false;

  final appRouter = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    refreshListenable: authRefresh,
    observers: [sessionNavigation],
    redirect: (context, state) {
      if (state.uri.hasScheme && state.uri.scheme == photoWidgetUrlScheme) {
        final widget = parsePhotoWidgetEntry(
          state.uri.toString(),
          scheme: photoWidgetUrlScheme,
        );
        if (widget != null) return photoWidgetReturnPath(widget);
      }
      final authState = ref.read(authNotifierProvider);
      final isLoggedIn = authState.value != null;

      final isOnLoginPage = state.matchedLocation == '/login';
      final isOnRecoveryPage = state.matchedLocation == '/recover';
      final isOnPasswordSetupPage = state.matchedLocation == '/set-password';
      final isOnOfflinePage = state.matchedLocation == '/offline';

      if (!isLoggedIn &&
          !isOnLoginPage &&
          !isOnRecoveryPage &&
          !isOnOfflinePage) {
        final returnPath = authenticationReturnPath(state.uri.toString());
        if (returnPath != '/') {
          return '/login?from=${Uri.encodeComponent(returnPath)}';
        }
        return '/login';
      }
      if (isOnPasswordSetupPage &&
          !ref.read(phonePasswordSetupRequiredProvider)) {
        return isLoggedIn
            ? authenticationReturnPath(state.uri.queryParameters['from'])
            : '/login';
      }
      if (isLoggedIn && isOnLoginPage) {
        if (ref.read(phonePasswordSetupRequiredProvider)) {
          final from = authenticationReturnPath(
            state.uri.queryParameters['from'],
          );
          return from == '/'
              ? '/set-password'
              : '/set-password?from=${Uri.encodeComponent(from)}';
        }
        return authenticationReturnPath(state.uri.queryParameters['from']);
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/photo-widget/:squadId',
        name: 'photoWidget',
        builder: (context, state) => PhotoWidgetEntryScreen(
          key: ValueKey(state.uri.toString()),
          entry: parsePhotoWidgetEntry(state.uri.toString()),
          cameraBuilder: (target) => PhotoComposerScreen(
            key: ValueKey(target),
            target: target,
            autoOpenCamera: true,
            onSent: () => context.go('/'),
          ),
        ),
      ),
      GoRoute(
        path: '/offline',
        name: 'offlineConversations',
        builder: (context, state) => const OfflineConversationsScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const _SessionHome(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/recover',
        name: 'passwordRecovery',
        builder: (context, state) => const PasswordRecoveryScreen(),
      ),
      GoRoute(
        path: '/set-password',
        name: 'passwordSetup',
        builder: (context, state) => const PasswordSetupScreen(),
      ),
      GoRoute(
        path: '/account/contacts',
        name: 'accountContacts',
        builder: (context, state) => const AccountContactsScreen(),
      ),
      GoRoute(
        path: '/invite/:credential',
        name: 'invitation',
        builder: (context, state) => InvitationLandingScreen(
          credential: state.pathParameters['credential']!,
        ),
      ),
      GoRoute(
        path: '/scenarios/fitness',
        name: 'fitness',
        builder: (context, state) =>
            const _ScenarioPage(title: '健身', child: FitnessScreen()),
      ),
      GoRoute(
        path: '/scenarios/finance',
        name: 'finance',
        builder: (context, state) =>
            const _ScenarioPage(title: '理财', child: FinanceScreen()),
      ),
      GoRoute(
        path: '/scenarios/travel',
        name: 'travel',
        builder: (context, state) =>
            const _ScenarioPage(title: '旅行', child: TravelScreen()),
      ),
      GoRoute(
        path: '/scenarios/food',
        name: 'food',
        builder: (context, state) =>
            const _ScenarioPage(title: '美食', child: FoodScreen()),
      ),
    ],
  );

  ref.listen(authNotifierProvider, (previous, next) {
    final previousId = previous?.value?.id;
    if (previousId != null && previousId != next.value?.id && !resetScheduled) {
      resetScheduled = true;
      // Auth notifications can arrive during a widget rebuild. Reset the
      // Navigator after that frame, including routes outside GoRouter's pages.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        resetScheduled = false;
        if (disposed) return;
        sessionNavigation.clearSessionOverlays();
        final userId = ref.read(authNotifierProvider).value?.id;
        appRouter.go(userId == null ? '/login' : '/');
      });
    }
    authRefresh.value++;
  });
  ref.onDispose(() {
    disposed = true;
    appRouter.dispose();
    authRefresh.dispose();
  });

  return appRouter;
}

class _SessionHome extends ConsumerWidget {
  const _SessionHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(
      authNotifierProvider.select((user) => user.value?.id),
    );
    final sessionKey = ValueKey(userId);
    const useDemoBackend = bool.fromEnvironment(
      'USE_DEMO_BACKEND',
      defaultValue: true,
    );
    return useDemoBackend
        ? HomeShellScreen(key: sessionKey)
        : RemoteHomeShellScreen(key: sessionKey);
  }
}

/// Imperative feature pages and dialogs are pageless routes. GoRouter can keep
/// them when the same home page remains matched across an account switch.
class _SessionNavigationObserver extends NavigatorObserver {
  final _routes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
  }

  void clearSessionOverlays() {
    final currentNavigator = navigator;
    if (currentNavigator == null) return;
    final messenger = ScaffoldMessenger.maybeOf(currentNavigator.context);
    messenger?.clearSnackBars();
    messenger?.removeCurrentSnackBar();
    messenger?.clearMaterialBanners();
    messenger?.removeCurrentMaterialBanner();
    for (final route in _routes.reversed.toList(growable: false)) {
      if (route.settings is! Page<dynamic> && route.isActive) {
        currentNavigator.removeRoute(route);
      }
    }
  }
}

class _ScenarioPage extends StatelessWidget {
  const _ScenarioPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: child,
  );
}
