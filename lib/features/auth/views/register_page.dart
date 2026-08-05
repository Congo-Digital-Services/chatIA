import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
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

  @override
  void dispose() {
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
                              ? const CircularProgressIndicator(strokeWidth: 2)
                              : const Text('Créer mon compte'),
                        ),
                      ),
                      if (auth.infoMessage != null)
                        _message(auth.infoMessage!, Colors.green),
                      if (auth.errorMessage != null)
                        _message(auth.errorMessage!, Colors.redAccent),
                      if (auth.infoMessage != null)
                        TextButton.icon(
                          onPressed: auth.isLoading
                              ? null
                              : () => ref
                                    .read(authControllerProvider)
                                    .resendVerificationEmail(
                                      _email.text.trim(),
                                    ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text(
                            'Renvoyer l’e-mail de vérification',
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

  Widget _message(String message, Color color) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(color: color),
    ),
  );
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
  void _register() {
    final auth = ref.read(authControllerProvider);
    final name = _name.text.trim();
    final username = _username.text.trim();
    final email = _email.text.trim();
    if (name.length < 3 ||
        email.isEmpty ||
        _password.text.isEmpty ||
        _confirmation.text.isEmpty) {
      auth.setErrorMessage('Veuillez remplir tous les champs obligatoires.');
      return;
    }
    if (!email.contains('@')) {
      auth.setErrorMessage('Veuillez renseigner une adresse e-mail valide.');
      return;
    }
    if (username.isNotEmpty && (username.length < 2 || username.length > 80)) {
      auth.setErrorMessage(
        'Le nom d’utilisateur doit contenir entre 2 et 80 caractères.',
      );
      return;
    }
    if (_password.text.length < 8 || _password.text.length > 128) {
      auth.setErrorMessage(
        'Le mot de passe doit contenir entre 8 et 128 caractères.',
      );
      return;
    }
    if (_password.text != _confirmation.text) {
      auth.setErrorMessage('Les mots de passe ne correspondent pas.');
      return;
    }
    auth.register(
      name: name,
      username: username,
      email: email,
      password: _password.text,
      confirmPassword: _confirmation.text,
    );
  }
}
