import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/backend_config.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/button_loader.dart';
import '../providers/auth_state_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  bool _hidePassword = true;
  ProviderSubscription<AuthController>? _authSubscription;
  String? _lastErrorToast;
  String? _lastInfoToast;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: BackendConfig.authEmail);
    _password = TextEditingController(text: BackendConfig.authPassword);
    _authSubscription = ref.listenManual<AuthController>(
      authControllerProvider,
      (previous, next) {
        if (!mounted) return;
        final error = next.errorMessage;
        if (error == null || error.isEmpty) {
          _lastErrorToast = null;
        }
        if (error != null && error.isNotEmpty && _lastErrorToast != error) {
          _lastErrorToast = error;
          showAppToast(context, message: error, type: AppToastType.error);
        }
        final info = next.infoMessage;
        if (info != null && info.isNotEmpty && _lastInfoToast != info) {
          _lastInfoToast = info;
          showAppToast(
            context,
            message:
                'Un nouvel e-mail de vérification a été envoyé. '
                'Pensez à vérifier vos spams.',
            type: AppToastType.success,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (auth.isRestoring)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppThemeColors.background,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AppThemeColors.shellGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  children: [
                    Image.asset('assets/icons/congo_logo.png', height: 92),
                    const SizedBox(height: 20),
                    Text('LobaIA', style: theme.textTheme.displaySmall),
                    const SizedBox(height: 8),
                    Text(
                      'Votre espace de travail intelligent',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppThemeColors.textSoft,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppThemeColors.surface.withValues(alpha: .96),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppThemeColors.stroke),
                        boxShadow: AppThemeShadows.medium,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Bon retour',
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Connectez-vous pour retrouver vos conversations.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppThemeColors.textSoft,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _field(
                            _email,
                            'Adresse e-mail',
                            auth.isLoading,
                            keyboard: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            _password,
                            'Mot de passe',
                            auth.isLoading,
                            password: true,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: auth.isLoading ? null : _signIn,
                              child: auth.isLoading
                                  ? const ButtonLoader()
                                  : const Text('Se connecter'),
                            ),
                          ),
                          TextButton(
                            onPressed: auth.isLoading
                                ? null
                                : () => context.go('/forgot-password'),
                            child: const Text('Mot de passe oublié ?'),
                          ),
                          if (auth.errorMessage?.contains(
                                'n’est pas vérifié',
                              ) ??
                              false)
                            TextButton.icon(
                              onPressed: auth.isLoading
                                  ? null
                                  : () => ref
                                        .read(authControllerProvider)
                                        .resendVerificationEmail(
                                          _email.text.trim(),
                                        ),
                              icon: const Icon(
                                Icons.mark_email_unread_outlined,
                              ),
                              label: const Text(
                                'Renvoyer l’e-mail de vérification',
                              ),
                            ),
                          const SizedBox(height: 8),
                          Divider(color: AppThemeColors.stroke),
                          const SizedBox(height: 8),
                          Text(
                            'Vous n’avez pas encore de compte ?',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppThemeColors.textSoft,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              key: const Key('register_button'),
                              onPressed: auth.isLoading
                                  ? null
                                  : () => context.go('/register'),
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: const Text('Créer un compte'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    bool loading, {
    bool password = false,
    TextInputType? keyboard,
  }) => TextField(
    controller: controller,
    enabled: !loading,
    obscureText: password && _hidePassword,
    keyboardType: keyboard,
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppThemeColors.backgroundSoft,
      suffixIcon: password
          ? IconButton(
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
              ),
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
            )
          : null,
    ),
  );

  void _warn(String message) {
    showAppToast(context, message: message, type: AppToastType.warning);
  }

  void _signIn() {
    final email = _email.text.trim();
    final auth = ref.read(authControllerProvider);
    if (email.isEmpty || _password.text.isEmpty) {
      _warn('Veuillez remplir votre adresse e-mail et votre mot de passe.');
      return;
    }
    if (!email.contains('@')) {
      _warn('Veuillez renseigner une adresse e-mail valide.');
      return;
    }
    auth.signIn(email: email, password: _password.text);
  }
}
