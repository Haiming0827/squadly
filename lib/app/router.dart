import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/account_contacts_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/password_recovery_screen.dart';
import '../features/home/presentation/screens/home_shell_screen.dart';
import '../features/home/presentation/screens/remote_home_shell_screen.dart';
import '../features/squad/presentation/screens/invitation_landing_screen.dart';

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

@riverpod
GoRouter router(Ref ref) {
  final authRefresh = ValueNotifier(0);

  final appRouter = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final isLoggedIn = authState.valueOrNull != null;

      final isOnLoginPage = state.matchedLocation == '/login';
      final isOnRecoveryPage = state.matchedLocation == '/recover';

      if (!isLoggedIn && !isOnLoginPage && !isOnRecoveryPage) {
        final returnPath = invitationReturnPath(state.uri.toString());
        if (returnPath != '/') {
          return '/login?from=${Uri.encodeComponent(returnPath)}';
        }
        return '/login';
      }
      if (isLoggedIn && isOnLoginPage) {
        return invitationReturnPath(state.uri.queryParameters['from']);
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) {
          const useDemoBackend = bool.fromEnvironment(
            'USE_DEMO_BACKEND',
            defaultValue: true,
          );
          return useDemoBackend
              ? const HomeShellScreen()
              : const RemoteHomeShellScreen();
        },
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
    ],
  );

  ref.listen(authNotifierProvider, (previous, next) {
    authRefresh.value++;
  });
  ref.onDispose(() {
    appRouter.dispose();
    authRefresh.dispose();
  });

  return appRouter;
}
