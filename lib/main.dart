import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/services/auth_service.dart';
import 'core/services/http_client_factory.dart';
import 'core/services/local_auth_service.dart';
import 'core/services/token_storage_service.dart';
import 'core/services/url_strategy_helper.dart';
import 'features/auth/providers/auth_state_provider.dart';
import 'features/chat/providers/chat_state_provider.dart';
import 'features/settings/providers/settings_provider.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/maloba_glyph.dart';

void main() {
  configureUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ProviderScope(
      overrides: [
        tokenStorageServiceProvider.overrideWithValue(TokenStorageService()),
        authServiceProvider.overrideWith((ref) {
          final storage = ref.watch(tokenStorageServiceProvider);
          return LocalAuthService(
            storage: storage,
            clientFactory: createCredentialedClient,
          );
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
    final settings = ref.watch(settingsControllerProvider);
    final auth = ref.watch(authControllerProvider);
    ref.watch(chatControllerProvider);

    if (auth.isRestoring) {
      return _BrandedSplash(
        isDark: _resolvesDark(context, settings.themeMode),
        accentColor: settings.accentColor,
      );
    }

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'LobaIA',
      theme: AppTheme.build(isDark: false, accentColor: settings.accentColor),
      darkTheme: AppTheme.build(
        isDark: true,
        accentColor: settings.accentColor,
      ),
      themeMode: settings.themeMode,
      routerConfig: router,
      builder: (context, child) {
        AppThemeColors.syncWithContext(
          context,
          activeAccent: settings.accentColor,
        );

        if (!kIsWeb) {
          return child ?? const SizedBox.shrink();
        }

        return _MobileEmulatorWrapper(child: child ?? const SizedBox.shrink());
      },
    );
  }

  static bool _resolvesDark(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
      case ThemeMode.light:
        return false;
    }
  }
}

class _BrandedSplash extends StatelessWidget {
  const _BrandedSplash({required this.isDark, required this.accentColor});

  final bool isDark;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(isDark: isDark, accentColor: accentColor),
      home: Scaffold(
        backgroundColor: AppThemeColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MalobaGlyph(size: 120),
              const SizedBox(height: 20),
              Text(
                'LobaIA',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileEmulatorWrapper extends StatelessWidget {
  final Widget child;
  const _MobileEmulatorWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFD8D1C5),
      body: Center(
        child: Container(
          width: 390,
          height: 844,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(48),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.35),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: child,
        ),
      ),
    );
  }
}
