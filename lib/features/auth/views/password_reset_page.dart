import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_success_dialog.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/button_loader.dart';
import '../providers/auth_state_provider.dart';
import 'verify_email_page.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _email = TextEditingController();
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
        if (error != null && error.isNotEmpty && _lastErrorToast != error) {
          _lastErrorToast = error;
          showAppToast(context, message: error, type: AppToastType.error);
        }
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _email.dispose();
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
                child: Column(
                  children: [
                    Image.asset('assets/icons/congo_logo.png', height: 76),
                    const SizedBox(height: 16),
                    Text(
                      'Mot de passe oublié',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ne vous inquiétez pas, nous allons vous aider.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppThemeColors.textSoft,
                      ),
                    ),
                    const SizedBox(height: 26),
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: auth.isLoading
                                  ? null
                                  : () => context.go('/login'),
                              icon: const Icon(Icons.arrow_back_rounded),
                              label: const Text('Retour à la connexion'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppThemeColors.accentSoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.lock_reset_rounded,
                              color: AppThemeColors.accent,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Réinitialiser mon mot de passe',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Saisissez votre adresse e-mail ci-dessous. '
                            'Nous vous enverrons un lien sécurisé pour créer '
                            'un nouveau mot de passe.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppThemeColors.textSoft,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            controller: _email,
                            enabled: !auth.isLoading,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: InputDecoration(
                              labelText: 'Adresse e-mail',
                              filled: true,
                              fillColor: AppThemeColors.backgroundSoft,
                              prefixIcon: const Icon(
                                Icons.mail_outline_rounded,
                                size: 20,
                              ),
                            ),
                            onSubmitted: (_) => _requestReset(),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: auth.isLoading ? null : _requestReset,
                              child: auth.isLoading
                                  ? const ButtonLoader()
                                  : const Text(
                                      'Envoyer le lien de réinitialisation',
                                    ),
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

  void _warn(String message) {
    showAppToast(context, message: message, type: AppToastType.warning);
  }

  void _requestReset() {
    final email = _email.text.trim();
    if (email.isEmpty || !_isValidEmail(email)) {
      _warn('Veuillez renseigner une adresse e-mail valide.');
      return;
    }
    _successDialogShown = false;
    ref.read(authControllerProvider).requestPasswordReset(email);
  }

  bool _isValidEmail(String value) {
    return RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    ).hasMatch(value);
  }

  Future<void> _showSuccessDialog(String email) async {
    final target = email.isEmpty ? 'votre adresse e-mail' : email;
    await showAppSuccessDialog(
      context,
      title: 'E-mail envoyé !',
      message: 'Un lien de réinitialisation a été envoyé à $target.\n\n'
          'Vérifiez votre boîte de réception, ainsi que vos spams, '
          'puis cliquez sur le lien pour créer votre nouveau mot de passe.',
      onDone: () {
        ref.read(authControllerProvider).clearMessages();
        context.go('/login');
      },
    );
  }
}

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.userId,
    required this.token,
  });
  final String userId;
  final String token;
  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
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
        if (error != null && error.isNotEmpty && _lastErrorToast != error) {
          _lastErrorToast = error;
          showAppToast(context, message: error, type: AppToastType.error);
        }
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final invalid = widget.userId.isEmpty || widget.token.isEmpty;
    if (auth.infoMessage != null)
      return AuthResultScaffold(
        title: 'Mot de passe modifié',
        message:
            'Votre mot de passe a été modifié avec succès.\n'
            'Vous pouvez maintenant vous connecter avec votre nouveau mot de passe.',
        isError: false,
        actionLabel: 'Se connecter',
        onAction: () => context.go('/login'),
      );
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Nouveau mot de passe',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (invalid)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      'Ce lien de réinitialisation est incomplet.',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  )
                else ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nouveau mot de passe',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmation,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmer le mot de passe',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: auth.isLoading ? null : _submit,
                    child: auth.isLoading
                        ? const ButtonLoader()
                        : const Text('Enregistrer le mot de passe'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _warn(String message) {
    showAppToast(context, message: message, type: AppToastType.warning);
  }

  void _submit() {
    if (_password.text.length < 8) {
      _warn('Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }
    if (_password.text != _confirmation.text) {
      _warn('Les mots de passe ne correspondent pas.');
      return;
    }
    ref
        .read(authControllerProvider)
        .resetPassword(
          userId: widget.userId,
          token: widget.token,
          password: _password.text,
        );
  }
}
