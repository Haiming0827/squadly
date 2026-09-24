import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/router.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';

void main() {
  test(
    'keeps the router instance stable across authentication changes',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialRouter = container.read(routerProvider);

      await container
          .read(authNotifierProvider.notifier)
          .signInWithEmail(email: 'haiming@example.com', password: 'password1');

      expect(container.read(routerProvider), same(initialRouter));
    },
  );
}
