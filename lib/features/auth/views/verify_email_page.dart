import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_state_provider.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key, required this.email, required this.token});
  final String email;
  final String token;

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.email.isNotEmpty && widget.token.isNotEmpty) {
        ref
            .read(authControllerProvider)
            .verifyEmail(email: widget.email, token: widget.token);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final invalidLink = widget.email.isEmpty || widget.token.isEmpty;
    return AuthResultScaffold(
      title: 'Vérification de l’e-mail',
      message: invalidLink
          ? 'Ce lien de vérification est incomplet.'
          : (auth.isLoading
                ? 'Vérification en cours…'
                : (auth.errorMessage != null
                      ? auth.errorMessage!
                      : (auth.infoMessage != null
                            ? 'Votre adresse e-mail a été vérifiée avec succès.\n'
                                  'Vous pouvez maintenant vous connecter.'
                            : ''))),
      isError: invalidLink || auth.errorMessage != null,
      actionLabel: 'Aller à la connexion',
      onAction: () => context.go('/login'),
    );
  }
}

class AuthResultScaffold extends StatelessWidget {
  const AuthResultScaffold({
    required this.title,
    required this.message,
    required this.isError,
    required this.actionLabel,
    required this.onAction,
  });
  final String title;
  final String message;
  final bool isError;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.mark_email_read_outlined,
              size: 48,
              color: isError ? Colors.redAccent : Colors.green,
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    ),
  );
}
