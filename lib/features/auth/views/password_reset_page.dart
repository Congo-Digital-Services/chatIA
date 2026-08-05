import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
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

  @override
  void dispose() {
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
                                  ? const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    )
                                  : const Text(
                                      'Envoyer le lien de réinitialisation',
                                    ),
                            ),
                          ),
                          if (auth.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    size: 16,
                                    color: Colors.redAccent,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      auth.errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ],
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

  void _requestReset() {
    final email = _email.text.trim();
    if (email.isEmpty || !_isValidEmail(email)) {
      ref
          .read(authControllerProvider)
          .setErrorMessage('Veuillez renseigner une adresse e-mail valide.');
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
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final target = email.isEmpty ? 'votre adresse e-mail' : email;
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  child: Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: AppThemeColors.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mark_email_read_outlined,
                      size: 30,
                      color: AppThemeColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'E-mail envoyé !',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  'Un lien de réinitialisation a été envoyé à $target.\n\n'
                  'Vérifiez votre boîte de réception, ainsi que vos spams, '
                  'puis cliquez sur le lien pour créer votre nouveau mot de passe.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppThemeColors.textSoft,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: () {
                      ref.read(authControllerProvider).clearMessages();
                      Navigator.of(ctx).pop();
                      context.go('/login');
                    },
                    child: const Text('Compris'),
                  ),
                ),
              ],
            ),
          ),
        );
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
  @override
  void dispose() {
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
        message: auth.infoMessage!,
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
                    child: const Text('Enregistrer le mot de passe'),
                  ),
                ],
                if (auth.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      auth.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_password.text.length < 8) {
      ref
          .read(authControllerProvider)
          .setErrorMessage(
            'Le mot de passe doit contenir au moins 8 caractères.',
          );
      return;
    }
    if (_password.text != _confirmation.text) {
      ref
          .read(authControllerProvider)
          .setErrorMessage('Les mots de passe ne correspondent pas.');
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
