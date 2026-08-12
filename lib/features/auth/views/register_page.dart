import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_success_dialog.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/button_loader.dart';
import '../providers/auth_state_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});
  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _hidePassword = true;
  bool _successDialogShown = false;
  ProviderSubscription<AuthController>? _authSubscription;
  String? _lastErrorToast;

  @override
  void initState() {
    super.initState();
    _authSubscription = ref.listenManual<AuthController>(
      authControllerProvider,
      (previous, next) {
        if (!mounted) return;
        final error = next.errorMessage;
        if (error == null || error.isEmpty) {
          _lastErrorToast = null;
          return;
        }
        if (_lastErrorToast != error) {
          _lastErrorToast = error;
          showAppToast(context, message: error, type: AppToastType.error);
        }
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    final success =
        auth.infoMessage != null &&
        auth.errorMessage == null &&
        !auth.isLoading;
    if (success && !_successDialogShown) {
      _successDialogShown = true;
      final email = _email.text.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showSuccessDialog(email);
      });
    }

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
                child: Container(
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => context.go('/login'),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Retour à la connexion'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppThemeColors.accent.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.person_add_alt_1_rounded,
                          color: AppThemeColors.accent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Créer votre compte',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Nous vous enverrons un lien de vérification par e-mail.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppThemeColors.textSoft,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _field(_name, 'Nom complet', auth.isLoading),
                      const SizedBox(height: 12),
                      _field(
                        _username,
                        'Nom d’utilisateur (optionnel)',
                        auth.isLoading,
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 12),
                      _field(
                        _confirmation,
                        'Confirmer le mot de passe',
                        auth.isLoading,
                        password: true,
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: auth.isLoading ? null : _register,
                          child: auth.isLoading
                              ? const ButtonLoader()
                              : const Text('Créer mon compte'),
                        ),
                      ),
                    ],
                  ),
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

  Future<void> _showSuccessDialog(String email) async {
    final target = email.isEmpty ? 'votre adresse e-mail' : email;
    await showAppSuccessDialog(
      context,
      title: 'Inscription réussie',
      message:
          'Pour activer votre compte, un e-mail de vérification a été '
          'envoyé à $target.\n\n'
          'Ouvrez-le puis cliquez sur le lien de confirmation (ou saisissez '
          'le code fourni) pour vérifier votre compte.\n'
          'Pensez également à vérifier vos spams.',
      onDone: () {
        ref.read(authControllerProvider).clearMessages();
        context.go('/login');
      },
    );
  }

  void _register() {
    final auth = ref.read(authControllerProvider);
    final name = _name.text.trim();
    final username = _username.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty) {
      _warn('Veuillez renseigner votre nom complet.');
      return;
    }
    if (name.length < 3) {
      _warn('Le nom complet doit contenir au moins 3 caractères.');
      return;
    }
    if (email.isEmpty) {
      _warn('Veuillez renseigner votre adresse e-mail.');
      return;
    }
    if (!email.contains('@')) {
      _warn('Veuillez renseigner une adresse e-mail valide.');
      return;
    }
    if (_password.text.isEmpty) {
      _warn('Veuillez renseigner votre mot de passe.');
      return;
    }
    if (_password.text.length < 8 || _password.text.length > 128) {
      _warn('Le mot de passe doit contenir entre 8 et 128 caractères.');
      return;
    }
    if (_confirmation.text.isEmpty) {
      _warn('Veuillez confirmer votre mot de passe.');
      return;
    }
    if (_password.text != _confirmation.text) {
      _warn('Les mots de passe ne correspondent pas.');
      return;
    }
    if (username.isNotEmpty && (username.length < 2 || username.length > 80)) {
      _warn('Le nom d’utilisateur doit contenir entre 2 et 80 caractères.');
      return;
    }
    _successDialogShown = false;
    auth.register(
      name: name,
      username: username,
      email: email,
      password: _password.text,
      confirmPassword: _confirmation.text,
    );
  }
}
