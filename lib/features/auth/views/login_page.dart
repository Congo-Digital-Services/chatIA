import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/backend_config.dart';
import '../../../shared/theme/app_theme.dart';
import '../providers/auth_state_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _confirmation;
  bool _register = false;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: BackendConfig.authEmail);
    _password = TextEditingController(text: BackendConfig.authPassword);
    _name = TextEditingController();
    _username = TextEditingController();
    _confirmation = TextEditingController();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _username.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (auth.isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: AppThemeColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                Image.asset('assets/icons/congo_logo.png', height: 104),
                const SizedBox(height: 24),
                Text('ChatIA', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 36),
                Text(
                  _register ? 'Créer un compte' : 'Connexion',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                if (_register) ...[
                  _field(_name, 'Nom complet', auth.isLoading),
                  const SizedBox(height: 12),
                  _field(_username, 'Nom d’utilisateur', auth.isLoading),
                  const SizedBox(height: 12),
                ],
                _field(
                  _email,
                  'Adresse e-mail',
                  auth.isLoading,
                  keyboard: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _field(_password, 'Mot de passe', auth.isLoading, password: true),
                if (_register) ...[
                  const SizedBox(height: 12),
                  _field(
                    _confirmation,
                    'Confirmer le mot de passe',
                    auth.isLoading,
                    password: true,
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: auth.isLoading ? null : _submit,
                    child: Text(
                      auth.isLoading
                          ? 'Connexion en cours…'
                          : (_register ? 'Créer un compte' : 'Continuer'),
                    ),
                  ),
                ),
                if (auth.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      auth.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                if (auth.infoMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      auth.infoMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                TextButton(
                  onPressed: auth.isLoading
                      ? null
                      : () => setState(() {
                          _register = !_register;
                          ref.read(authControllerProvider).clearMessages();
                        }),
                  child: Text(
                    _register ? 'J’ai déjà un compte' : 'Créer un compte',
                  ),
                ),
              ],
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
      suffixIcon: password
          ? IconButton(
              icon: Icon(_hidePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
            )
          : null,
    ),
  );

  void _submit() {
    final auth = ref.read(authControllerProvider);
    if (_register) {
      if (_password.text != _confirmation.text) {
        auth.setErrorMessage('Les mots de passe ne correspondent pas.');
        return;
      }
      auth.register(
        name: _name.text.trim(),
        username: _username.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        confirmPassword: _confirmation.text,
      );
      return;
    }
    auth.signIn(email: _email.text.trim(), password: _password.text);
  }
}
