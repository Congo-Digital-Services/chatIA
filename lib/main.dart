import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/services/auth_service.dart';
import 'core/services/keycloak_auth_service.dart';
import 'core/services/token_storage_service.dart';
import 'features/auth/providers/auth_state_provider.dart';
import 'features/chat/providers/chat_state_provider.dart';
import 'shared/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ProviderScope(
      overrides: [
        tokenStorageServiceProvider.overrideWithValue(TokenStorageService()),
        authServiceProvider.overrideWith((ref) {
          final storage = ref.watch(tokenStorageServiceProvider);
          return KeycloakAuthService(storage: storage);
        }),
      ],
      child: const ChatIAApp(),
    ),
  );
}

class ChatIAApp extends ConsumerWidget {
  const ChatIAApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    ref.watch(authControllerProvider);
    ref.watch(chatControllerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'ChatIA',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
